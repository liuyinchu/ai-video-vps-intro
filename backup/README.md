# 完整工程备份

备份日期：2026-10-24（Asia/Shanghai）

原始远端工程：
yangshuyun@10.10.10.1:/Users/yangshuyun/workspace/dev/ai-video/test-1024-astra

## 备份内容

- complete-project-2026-10-24.tar.gz：完整原始远端目录，包含 .git、build、output，以及通常被 Git 忽略的配音缓存、编译程序、中间视频、旧配音版本和检查图片。
- source-file-manifest.tsv：原始目录全部 173 个常规文件的 SHA256、字节数、八进制权限和相对路径，以制表符分隔。
- SHA256SUMS：完整快照的 SHA256。
- local-only-assets/：6 张仅在本地留存的历史画面检查图。
- local-cache-inventory.json：本次任务本地缓存 25 个文件的来源路径、大小、SHA256 和备份对应关系。
- verify-snapshot.rb：不依赖第三方库的恢复核对脚本。
- verification.json：从 GitHub 重新克隆、解包后生成的核对结果。

仓库根目录保留可浏览的源码、文案和成品。完整快照是恢复全部工程文件的依据，包含原始 Git 元数据。原始工程尚无提交；GitHub 的新提交记录本次备份。

## 恢复与核对

在仓库根目录执行：

    shasum -a 256 -c backup/SHA256SUMS
    mkdir restored-project
    tar -xzf backup/complete-project-2026-10-24.tar.gz -C restored-project
    ruby backup/verify-snapshot.rb restored-project backup/source-file-manifest.tsv

核对脚本逐一验证文件 SHA256、大小和权限，并确认没有遗漏或额外常规文件。原始目录没有符号链接。tar 同时保留空目录。

本地独有的历史检查图片可从 backup/local-only-assets/ 单独恢复；其来源映射见 local-cache-inventory.json。图片不影响最新成片与工程重建。

