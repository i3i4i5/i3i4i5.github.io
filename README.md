# 我的越狱软件源

同时提供 **无根 (rootless)** 与 **隐根 (RootHide)** 两种包，Sileo / Zebra / Cydia 通用。

## 源地址

```
https://i3i4i5.github.io/
```

## 目录结构

```
.
├── debs/                     # 所有 .deb 放这里
├── Packages                  # 由脚本生成
├── Packages.gz
├── Packages.bz2
├── Release                   # 由脚本生成
├── repo-key.gpg              # 若启用签名
├── index.html                # 源主页（可选，好看）
├── CydiaIcon.png             # 源图标 512x512（可选）
└── scripts/
    ├── make-index.sh         # 重建索引
    └── add-deb.sh            # 加包 + 重建
```

## 日常流程

```bash
# 1. 打包出新 deb 后，加进源
bash scripts/add-deb.sh ../out/MyTweak_1.0.0-rootless_iphoneos-arm64.deb

# 2. 推上去
git add -A && git commit -m "add MyTweak 1.0.0" && git push
```

push 之后 GitHub Actions 会自动重跑索引（见 `.github/workflows/build-repo.yml`）。

## 无根 vs 隐根 —— 关键区别

| 项目 | 无根 rootless | 隐根 RootHide |
|---|---|---|
| Architecture | `iphoneos-arm64` | `iphoneos-arm64`（旧版用 `iphoneos-arm64e`） |
| 安装路径 | `/var/jb/Library/...` | `./Library/...`（无 `/var/jb`） |
| Depends | `ellekit \| mobilesubstrate` | `ellekit \| mobilesubstrate`（不加 firmware） |
| 打包器 | theos 默认 | 需 roothide patcher，或手工 dpkg-deb |

**同一个包名、同一版本号，两个架构变体放在 debs/ 里会冲突**。推荐做法：

- 方案 A：版本号加后缀，`1.0.0` 给无根，`1.0.0+roothide` 给隐根，分两个包名更清晰
- 方案 B：包名不同，`com.you.tweak` 与 `com.you.tweak.roothide`

否则 Sileo 只会显示其中一个。

## 源图标

放 `CydiaIcon.png`（512×512 PNG）到仓库根目录即可，Sileo 会自动抓取。

## 签名（可选）

不签名也能用，Sileo 首次会提示「未验证的源」，允许即可。想签名：

```bash
gpg --full-generate-key          # 一次性
export GPG_KEY=你的KEYID
bash scripts/make-index.sh
```

自动化签名把私钥放进 GitHub Secrets：
- `GPG_PRIVATE_KEY` — `gpg --armor --export-secret-keys KEYID` 的内容
- `GPG_KEY_ID` — 短 ID

## Pages 设置

Settings → Pages → Source: **Deploy from a branch** → `main` / `/ (root)`。

## 限制

- 单文件 ≤ 100MB，仓库 ≤ 1GB（GitHub Pages 硬限制）
- 包大了改用 Releases，`Filename` 字段指向 release 直链
