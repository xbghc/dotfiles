-- vim-abolish:
--   cr{s,c,m,u,-,.,<space>}  coerce the word under the cursor to another naming style
--                            snake_case / camelCase / MixedCase / UPPER_CASE / kebab-case / dot.case / space separated
--                            (aliases: cr_=s, crp=m, crU=u, crk=-)
--   :S/old/new/g             case-preserving substitute (:Subvert); matches lowercase / UPPERCASE / MixedCase,
--                            supports {a,b} variants, e.g. :%S/facilit{y,ies}/building{,s}/g
--   :Abolish                 insert-mode abbreviations / typo correction
return {
  "tpope/vim-abolish",
  vscode = true,
  cmd = { "S", "Subvert", "Abolish" },
  keys = {
    { "cr", desc = "Coerce Case (abolish)" },
  },
}
