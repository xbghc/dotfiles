-- mini.ai 默认的 an/in（next textobject）会覆盖 nvim 0.12 内置的
-- treesitter 增量选择（an 扩大到父节点 / in 缩小到子节点），这里关掉。
-- mini.ai 默认 search_method = "cover_or_next"，a( 等本身就会找下一个，影响不大。
return {
  "nvim-mini/mini.ai",
  opts = {
    mappings = {
      around_next = "",
      inside_next = "",
    },
  },
}
