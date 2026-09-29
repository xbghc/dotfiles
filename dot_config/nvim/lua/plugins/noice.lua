-- noice 的 hover 对每个 LSP 响应单独渲染，后返回的会覆盖先返回的；
-- 关掉后使用 nvim 原生 hover，多个 LSP 的结果会合并显示
return {
  "folke/noice.nvim",
  opts = {
    lsp = {
      hover = { enabled = false },
    },
  },
}
