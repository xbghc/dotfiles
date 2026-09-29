-- vim-abolish：
--   cr{s,c,m,u,-,.,<space>}  转换光标下单词的命名风格
--                            snake_case / camelCase / MixedCase / UPPER_CASE / kebab-case / dot.case / 空格分隔
--                            （别名：cr_=s, crp=m, crU=u, crk=-）
--   :S/old/new/g             保留大小写的智能替换（:Subvert），匹配 小写 / 大写 / MixedCase 三种形式，
--                            支持 {a,b} 变体，如 :%S/facilit{y,ies}/building{,s}/g
--   :Abolish                 插入模式自动纠错
return {
  "tpope/vim-abolish",
  cmd = { "S", "Subvert", "Abolish" },
  keys = {
    { "cr", desc = "Coerce Case (abolish)" },
  },
}
