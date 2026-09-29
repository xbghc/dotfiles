# dotfiles

由 [chezmoi](https://chezmoi.io) 管理。

## 新机器
```sh
chezmoi init --apply xbghc
```
Windows 需额外设置用户环境变量 `XDG_CONFIG_HOME=%USERPROFILE%\.config`，让 nvim 读取 `~/.config/nvim`。

## 日常
- 修改后：`chezmoi re-add` → `chezmoi cd` → git commit/push
- 拉取更新：`chezmoi update`
