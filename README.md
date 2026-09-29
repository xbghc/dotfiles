# dotfiles

由 [chezmoi](https://chezmoi.io) 管理。

## 新机器
```sh
chezmoi init --apply xbghc
```
Windows 上会自动创建联接 `%LOCALAPPDATA%\nvim` → `~/.config/nvim`（若该目录已存在需先移走）。

## 日常
- 修改后：`chezmoi re-add`（nvim 的 lazy-lock.json 不同步，各机器自行维护） → `chezmoi cd` → git commit/push
- 拉取更新：`chezmoi update`
