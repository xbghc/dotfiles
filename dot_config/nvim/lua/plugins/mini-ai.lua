-- mini.ai's default an/in (next textobject) overrides nvim 0.12's built-in
-- treesitter incremental selection (an: parent node / in: child node), so disable them.
-- mini.ai's default search_method = "cover_or_next" already finds the next one for a( etc., so little is lost.
return {
  "nvim-mini/mini.ai",
  opts = {
    mappings = {
      around_next = "",
      inside_next = "",
    },
  },
}
