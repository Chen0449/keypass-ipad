// 用 GitHub REST API 建仓 + 单次提交上传全部文件 + 手动触发 Actions + 盯构建 + 拉产物。
//
// 用法：
//   node push-to-github.mjs setup   D:\dsh\02-临时\gh-token.txt
//   node push-to-github.mjs watch   D:\dsh\02-临时\gh-token.txt
//   node push-to-github.mjs get     D:\dsh\02-临时\gh-token.txt
//
// 令牌不落盘、不打印：只从这个文件读一次。
import fs from "node:fs";
import path from "node:path";

const ROOT = "D:\\dsh\\00-项目\\keypass-ipad";
const REPO = "keypass-ipad";
const BRANCH = "main";
const WORKFLOW = "build-ipa.yml";
const SKIP_DIRS = new Set([".git", "build", "out", "node_modules"]);

const [, , command, tokenFile] = process.argv;
if (!command || !tokenFile) {
  console.error("用法: node push-to-github.mjs <setup|watch|get> <token文件路径>");
  process.exit(2);
}
const token = fs.readFileSync(tokenFile.trim(), "utf8").trim();
if (!token) {
  console.error("令牌文件是空的");
  process.exit(2);
}

const API = "https://api.github.com";
const headers = {
  Authorization: `Bearer ${token}`,
  Accept: "application/vnd.github+json",
  "User-Agent": "dsh-keypass",
  "X-GitHub-Api-Version": "2022-11-28"
};

async function api(method, url, body) {
  const res = await fetch(url.startsWith("http") ? url : API + url, {
    method,
    headers: body ? { ...headers, "Content-Type": "application/json" } : headers,
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: res.status, ok: res.ok, json, text };
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(path.join(dir, entry.name), out);
    } else {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

async function whoami() {
  const res = await api("GET", "/user");
  if (!res.ok) throw new Error(`令牌无效或没权限（HTTP ${res.status}）：${res.text.slice(0, 200)}`);
  return { login: res.json.login, plan: res.json.plan?.name };
}

async function ensureRepo(login) {
  const exists = await api("GET", `/repos/${login}/${REPO}`);
  if (exists.ok) {
    console.log(`仓库已存在: ${exists.json.html_url}  public=${!exists.json.private}`);
    return exists.json;
  }
  const created = await api("POST", "/user/repos", {
    name: REPO,
    description: "iPad 密码库键盘（Keyboard Extension + Swift）",
    private: false,
    has_issues: false,
    has_wiki: false,
    auto_init: false
  });
  if (!created.ok) throw new Error(`建仓失败 HTTP ${created.status}: ${created.text.slice(0, 300)}`);
  console.log(`建仓成功: ${created.json.html_url}（public 仓库的 macOS runner 不花额度）`);
  return created.json;
}

/// 用 Git Data API 做**单次提交**：19 个 blob → 1 棵树 → 1 个 commit → 移动分支。
/// 之前是每个文件一个 commit，结果一个 push 触发 18 次工作流，全在排队。
async function commitAll(login) {
  const files = walk(ROOT);
  console.log(`准备提交 ${files.length} 个文件（单次 commit）…`);

  const refRes = await api("GET", `/repos/${login}/${REPO}/git/ref/heads/${BRANCH}`);
  let parentSha = null;
  let baseTree = null;
  if (refRes.ok) {
    parentSha = refRes.json.object.sha;
    const commitRes = await api("GET", `/repos/${login}/${REPO}/git/commits/${parentSha}`);
    if (commitRes.ok) baseTree = commitRes.json.tree.sha;
  }

  const treeItems = [];
  let index = 0;
  for (const abs of files) {
    const rel = path.relative(ROOT, abs).split(path.sep).join("/");
    const blob = await api("POST", `/repos/${login}/${REPO}/git/blobs`, {
      content: fs.readFileSync(abs).toString("base64"),
      encoding: "base64"
    });
    if (!blob.ok) throw new Error(`上传 blob 失败 ${rel} HTTP ${blob.status}: ${blob.text.slice(0, 160)}`);
    treeItems.push({ path: rel, mode: "100644", type: "blob", sha: blob.json.sha });
    index += 1;
    process.stdout.write(`\r  已上传 ${index}/${files.length}  `);
  }
  console.log("");

  const treeBody = { tree: treeItems };
  if (baseTree) treeBody.base_tree = baseTree;
  const tree = await api("POST", `/repos/${login}/${REPO}/git/trees`, treeBody);
  if (!tree.ok) throw new Error(`建树失败 HTTP ${tree.status}: ${tree.text.slice(0, 200)}`);

  const commitBody = { message: "同步源码与构建配置", tree: tree.json.sha };
  if (parentSha) commitBody.parents = [parentSha];
  const commit = await api("POST", `/repos/${login}/${REPO}/git/commits`, commitBody);
  if (!commit.ok) {
    const hint = /workflow/i.test(commit.text) ? "  ← 令牌缺 workflow 权限" : "";
    throw new Error(`建 commit 失败 HTTP ${commit.status}: ${commit.text.slice(0, 200)}${hint}`);
  }

  if (parentSha) {
    const upd = await api("PATCH", `/repos/${login}/${REPO}/git/refs/heads/${BRANCH}`, { sha: commit.json.sha });
    if (!upd.ok) throw new Error(`移动分支失败 HTTP ${upd.status}: ${upd.text.slice(0, 200)}`);
  } else {
    const cr = await api("POST", `/repos/${login}/${REPO}/git/refs`, {
      ref: `refs/heads/${BRANCH}`,
      sha: commit.json.sha
    });
    if (!cr.ok) throw new Error(`建分支失败 HTTP ${cr.status}: ${cr.text.slice(0, 200)}`);
  }

  console.log(`提交完成: ${commit.json.sha.slice(0, 8)}`);
  return commit.json.sha;
}

async function dispatch(login) {
  const res = await api("POST", `/repos/${login}/${REPO}/actions/workflows/${WORKFLOW}/dispatches`, {
    ref: BRANCH
  });
  if (!res.ok) throw new Error(`触发工作流失败 HTTP ${res.status}: ${res.text.slice(0, 200)}`);
  console.log("已触发 workflow_dispatch");
}

async function findRun(login, sha) {
  const res = await api("GET", `/repos/${login}/${REPO}/actions/runs?per_page=10`);
  if (!res.ok) return null;
  const runs = res.json.workflow_runs ?? [];
  return runs.find((r) => r.head_sha === sha) ?? runs[0] ?? null;
}

async function watch(login, sha) {
  const started = Date.now();
  for (;;) {
    const run = await findRun(login, sha);
    if (run) {
      const elapsed = Math.round((Date.now() - started) / 1000);
      process.stdout.write(`\r  [${elapsed}s] ${run.name} · ${run.status}/${run.conclusion ?? "-"}   `);
      if (run.status === "completed") {
        console.log(`\n构建结束: ${run.conclusion}`);
        console.log(`  ${run.html_url}`);
        const jobs = await api("GET", `/repos/${login}/${REPO}/actions/runs/${run.id}/jobs`);
        for (const job of jobs.json?.jobs ?? []) {
          console.log(`  任务 ${job.name}: ${job.conclusion ?? job.status}`);
          for (const step of job.steps ?? []) {
            const mark = step.conclusion === "success" ? "OK  " : step.conclusion === "skipped" ? "--  " : "FAIL";
            console.log(`    ${mark} ${step.name}`);
          }
        }
        fs.writeFileSync("D:\\dsh\\02-临时\\last-run.json", JSON.stringify({ runId: run.id, conclusion: run.conclusion }, null, 2));
        return run;
      }
    }
    if (Date.now() - started > 25 * 60 * 1000) {
      console.log("\n等了 25 分钟还没结束，先停。稍后用 watch 再看。");
      return null;
    }
    await new Promise((r) => setTimeout(r, 10000));
  }
}

async function getArtifacts(login, runId) {
  const res = await api("GET", `/repos/${login}/${REPO}/actions/runs/${runId}/artifacts`);
  if (!res.ok) throw new Error(`列产物失败 HTTP ${res.status}`);
  const artifacts = res.json.artifacts ?? [];
  if (!artifacts.length) { console.log("没有产物（构建大概失败了）"); return; }

  fs.mkdirSync("D:\\dsh\\02-临时\\gh-out", { recursive: true });
  for (const art of artifacts) {
    const meta = await fetch(`${API}/repos/${login}/${REPO}/actions/artifacts/${art.id}/zip`, {
      headers, redirect: "manual"
    });
    const location = meta.headers.get("location");
    if (!location) { console.log(`拿不到 ${art.name} 的下载地址（HTTP ${meta.status}）`); continue; }
    const zipRes = await fetch(location, { redirect: "follow" });
    const buf = Buffer.from(await zipRes.arrayBuffer());
    const out = `D:\\dsh\\02-临时\\gh-out\\${art.name}.zip`;
    fs.writeFileSync(out, buf);
    console.log(`下载 ${art.name} -> ${out}  (${Math.round(buf.length / 1024)} KB)`);
  }
}

const main = async () => {
  const me = await whoami();
  console.log(`登录身份: ${me.login}`);

  if (command === "setup") {
    await ensureRepo(me.login);
    const sha = await commitAll(me.login);
    await dispatch(me.login);
    await new Promise((r) => setTimeout(r, 8000));
    await watch(me.login, sha);
  } else if (command === "watch") {
    await watch(me.login, process.argv[4] ?? null);
  } else if (command === "get") {
    const saved = JSON.parse(fs.readFileSync("D:\\dsh\\02-临时\\last-run.json", "utf8"));
    await getArtifacts(me.login, saved.runId);
  } else {
    console.error(`未知命令 ${command}`);
    process.exit(2);
  }
};

main().catch((err) => {
  console.error(`\n失败: ${err.message}`);
  process.exit(1);
});
