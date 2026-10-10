-- VSCode (vscode-neovim) adaptation, loaded at the end of config/keymaps.lua when vim.g.vscode is set.
-- https://github.com/vscode-neovim/vscode-neovim
--
-- LazyVim imports its vscode extra automatically: only editing plugins stay enabled (plus specs marked
-- `vscode = true`), so everything that relied on a nvim UI (pickers, explorer, LSP, gitsigns, bufferline, ...)
-- is mapped to the VSCode equivalent here, on the same keys as in the terminal.
-- Already provided by vscode-neovim itself: gd gD gf gF gH gO K gh z= gq = gc, <C-w>…, <C-o>/<C-i>, gt/gT,
-- :e :q :sp :vs :tabn …, and the vim.lsp.buf / vim.ui.select / vim.ui.input shims.
-- Insert mode belongs to VSCode: insert-mode mappings and plugins (pairs, completion, snippets) don't apply.

local vscode = require("vscode")

local map = vim.keymap.set
local nx = { "n", "x" }

-- Notifications become VSCode toasts (they have no title, so prefix it)
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(msg, level, opts)
  local title = opts and opts.title
  vscode.notify(title and (title .. ": " .. msg) or msg, level)
end

local function leave_visual()
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end

-- Run a VSCode command. In visual mode vscode-neovim passes the selection along as the command's range,
-- so only leave visual mode once the command has run.
---@param command string
---@param args? table
local function action(command, args)
  return function()
    local opts = { args = args }
    if vim.fn.mode():match("[vV\22]") then
      opts.callback = function(err)
        if err then
          vim.notify(tostring(err), vim.log.levels.ERROR, { title = command })
        end
        leave_visual()
      end
    end
    vscode.action(command, opts)
  end
end

-- Flip a VSCode setting between two values (written to the user settings)
local function toggle(name, on, off)
  return function()
    local value = on
    if vscode.get_config(name) == on then
      value = off
    end
    vscode.update_config(name, value, "global")
    vim.notify(("%s = %s"):format(name, tostring(value)))
  end
end

-- Search the workspace for the visual selection, or the word under the cursor
local function search(command, args)
  return function()
    local query = vim.fn.expand("<cword>")
    local mode = vim.fn.mode()
    if mode:match("[vV\22]") then
      query = vim.trim(table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), " "))
      leave_visual()
    end
    vscode.action(command, { args = vim.tbl_extend("force", { query = query }, args or {}) })
  end
end

-- VSCode's "next problem" commands can't filter by severity, so walk the diagnostics ourselves
---@param forward boolean
---@param severity integer vscode.DiagnosticSeverity: 0 = Error, 1 = Warning
local function goto_diagnostic(forward, severity)
  return function()
    vscode.eval_async(
      [[
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;
        const starts = vscode.languages
          .getDiagnostics(editor.document.uri)
          .filter((d) => d.severity === args.severity)
          .map((d) => d.range.start)
          .sort((a, b) => a.compareTo(b));
        if (!starts.length) return;
        const cursor = editor.selection.active;
        const target = args.forward
          ? starts.find((p) => p.isAfter(cursor)) || starts[0]
          : starts.reverse().find((p) => p.isBefore(cursor)) || starts[0];
        editor.selection = new vscode.Selection(target, target);
        editor.revealRange(new vscode.Range(target, target), vscode.TextEditorRevealType.InCenterIfOutsideViewport);
        await vscode.commands.executeCommand("editor.action.showHover");
      ]],
      { args = { forward = forward, severity = severity } }
    )
  end
end

local function toggle_pin()
  vscode.eval_async([[
    const tab = vscode.window.tabGroups.activeTabGroup.activeTab;
    const command = tab && tab.isPinned ? "workbench.action.unpinEditor" : "workbench.action.pinEditor";
    await vscode.commands.executeCommand(command);
  ]])
end

-- stylua: ignore start

-- find / files
for _, lhs in ipairs({ "<leader><space>", "<leader>ff", "<leader>fF", "<leader>fg", "<leader>fr", "<leader>fR" }) do
  map("n", lhs, action("workbench.action.quickOpen"), { desc = "Find Files" })
end
map("n", "<leader>,", action("workbench.action.showAllEditorsByMostRecentlyUsed"), { desc = "Open Editors" })
map("n", "<leader>fb", action("workbench.action.showAllEditorsByMostRecentlyUsed"), { desc = "Open Editors" })
map("n", "<leader>fp", action("workbench.action.openRecent"), { desc = "Projects" })
map("n", "<leader>fn", action("workbench.action.files.newUntitledFile"), { desc = "New File" })
map("n", "<leader>e", action("workbench.view.explorer"), { desc = "Explorer" })
map("n", "<leader>fe", action("workbench.view.explorer"), { desc = "Explorer" })
map("n", "<leader>E", action("workbench.files.action.showActiveFileInExplorer"), { desc = "Reveal File in Explorer" })
map("n", "<leader>fE", action("workbench.files.action.showActiveFileInExplorer"), { desc = "Reveal File in Explorer" })

-- search
for _, lhs in ipairs({ "<leader>/", "<leader>sg", "<leader>sG" }) do
  map("n", lhs, action("workbench.action.findInFiles"), { desc = "Grep" })
end
map(nx, "<leader>sw", search("workbench.action.findInFiles", { triggerSearch = true, matchWholeWord = true }), { desc = "Grep Selection or Word" })
map(nx, "<leader>sW", search("workbench.action.findInFiles", { triggerSearch = true }), { desc = "Grep Selection or Word (substring)" })
map("n", "<leader>sr", action("workbench.action.replaceInFiles"), { desc = "Search and Replace" })
map("x", "<leader>sr", search("workbench.action.replaceInFiles"), { desc = "Search and Replace" })
map("n", "<leader>sb", action("actions.find"), { desc = "Find in File" })
map("n", "<leader>sR", action("workbench.view.search"), { desc = "Resume (Search View)" })
map("n", "<leader>ss", action("workbench.action.gotoSymbol"), { desc = "Symbols" })
map("n", "<leader>sS", action("workbench.action.showAllSymbols"), { desc = "Workspace Symbols" })
map("n", "<leader>sd", action("workbench.actions.view.problems"), { desc = "Diagnostics" })
map("n", "<leader>sD", action("workbench.actions.view.problems"), { desc = "Diagnostics" })
map("n", "<leader>sm", action("nvimMarks.list"), { desc = "Marks" }) -- xbghc.nvim-marks, see plugins/vscode.lua
map("n", "<leader>sk", action("workbench.action.openGlobalKeybindings"), { desc = "Keymaps" })
map("n", "<leader>sC", action("workbench.action.showCommands"), { desc = "Commands" })
map("n", "<leader>sc", action("workbench.action.showCommands"), { desc = "Command History" })
map("n", "<leader>:", action("workbench.action.showCommands"), { desc = "Command History" })
-- same keywords as todo-comments
map("n", "<leader>st", action("workbench.action.findInFiles", { query = "\\b(TODO|FIX|FIXME|BUG|HACK|WARN|PERF|NOTE|TEST):", isRegex = true, isCaseSensitive = true, triggerSearch = true }), { desc = "Todo" })
map("n", "<leader>sT", action("workbench.action.findInFiles", { query = "\\b(TODO|FIX|FIXME):", isRegex = true, isCaseSensitive = true, triggerSearch = true }), { desc = "Todo/Fix/Fixme" })
-- the search view is VSCode's quickfix list
map("n", "]q", action("search.action.focusNextSearchResult"), { desc = "Next Search Result" })
map("n", "[q", action("search.action.focusPreviousSearchResult"), { desc = "Previous Search Result" })

-- code (LSP)
map("n", "gr", action("editor.action.goToReferences"), { desc = "References", nowait = true })
map("n", "gI", action("editor.action.goToImplementation"), { desc = "Goto Implementation" })
map("n", "gy", action("editor.action.goToTypeDefinition"), { desc = "Goto T[y]pe Definition" })
map("n", "gK", action("editor.action.triggerParameterHints"), { desc = "Signature Help" })
map("n", "gai", action("editor.showIncomingCalls"), { desc = "C[a]lls Incoming" })
map("n", "gao", action("editor.showOutgoingCalls"), { desc = "C[a]lls Outgoing" })
map("n", "<leader>ca", action("editor.action.quickFix"), { desc = "Code Action" })
-- with_insert hands the selection over to VSCode, so the action applies to it
map("x", "<leader>ca", function() vscode.with_insert(function() vscode.action("editor.action.quickFix") end) end, { desc = "Code Action" })
map("n", "<leader>cA", action("editor.action.sourceAction"), { desc = "Source Action" })
map("n", "<leader>cr", action("editor.action.rename"), { desc = "Rename" })
map("n", "<leader>cR", action("runCommands", { commands = { "workbench.files.action.showActiveFileInExplorer", "renameFile" } }), { desc = "Rename File" })
map("n", "<leader>cc", action("codelens.showLensesInCurrentLine"), { desc = "Run Codelens" })
map("n", "<leader>cs", action("outline.focus"), { desc = "Symbols (Outline)" })
map("n", "<leader>cf", action("editor.action.formatDocument"), { desc = "Format" })
map("x", "<leader>cf", "=", { desc = "Format", remap = true }) -- vscode-neovim's format operator
map("n", "<leader>cd", action("editor.action.showHover"), { desc = "Line Diagnostics" })
map("n", "]]", action("editor.action.wordHighlight.next"), { desc = "Next Reference" })
map("n", "[[", action("editor.action.wordHighlight.prev"), { desc = "Prev Reference" })

-- diagnostics
map("n", "]d", action("editor.action.marker.next"), { desc = "Next Diagnostic" })
map("n", "[d", action("editor.action.marker.prev"), { desc = "Prev Diagnostic" })
map("n", "]e", goto_diagnostic(true, 0), { desc = "Next Error" })
map("n", "[e", goto_diagnostic(false, 0), { desc = "Prev Error" })
map("n", "]w", goto_diagnostic(true, 1), { desc = "Next Warning" })
map("n", "[w", goto_diagnostic(false, 1), { desc = "Prev Warning" })
map("n", "<leader>xx", action("workbench.actions.view.problems"), { desc = "Diagnostics (Problems)" })
map("n", "<leader>xX", action("workbench.actions.view.problems"), { desc = "Diagnostics (Problems)" })

-- editors (buffers / tabs); <S-h>/<S-l> are mapped by LazyVim's vscode extra
map("n", "[b", action("workbench.action.previousEditor"), { desc = "Prev Editor" })
map("n", "]b", action("workbench.action.nextEditor"), { desc = "Next Editor" })
map("n", "[B", action("workbench.action.moveEditorLeftInGroup"), { desc = "Move Editor Left" })
map("n", "]B", action("workbench.action.moveEditorRightInGroup"), { desc = "Move Editor Right" })
map("n", "<leader>bb", action("workbench.action.openPreviousRecentlyUsedEditorInGroup"), { desc = "Switch to Other Editor" })
map("n", "<leader>`", action("workbench.action.openPreviousRecentlyUsedEditorInGroup"), { desc = "Switch to Other Editor" })
map("n", "<leader>bd", action("workbench.action.closeActiveEditor"), { desc = "Close Editor" })
map("n", "<leader>bD", action("workbench.action.closeEditorsAndGroup"), { desc = "Close Editor Group" })
map("n", "<leader>bo", action("workbench.action.closeOtherEditors"), { desc = "Close Other Editors" })
map("n", "<leader>br", action("workbench.action.closeEditorsToTheRight"), { desc = "Close Editors to the Right" })
map("n", "<leader>bl", action("workbench.action.closeEditorsToTheLeft"), { desc = "Close Editors to the Left" })
map("n", "<leader>bp", toggle_pin, { desc = "Toggle Pin" })
-- LazyVim runs the real :tab* commands; use vscode-neovim's editor-based replacements instead
map("n", "<leader><tab>l", "<cmd>Tablast<cr>", { desc = "Last Editor" })
map("n", "<leader><tab>f", "<cmd>Tabfirst<cr>", { desc = "First Editor" })
map("n", "<leader><tab>o", "<cmd>Tabonly<cr>", { desc = "Close Other Editors" })
map("n", "<leader><tab><tab>", "<cmd>Tabnew<cr>", { desc = "New Editor" })
map("n", "<leader><tab>]", "<cmd>Tabnext<cr>", { desc = "Next Editor" })
map("n", "<leader><tab>[", "<cmd>Tabprevious<cr>", { desc = "Previous Editor" })
map("n", "<leader><tab>d", "<cmd>Tabclose<cr>", { desc = "Close Editor" })
-- the real :qa would kill the embedded nvim
map("n", "<leader>qq", action("workbench.action.closeWindow"), { desc = "Close Window" })

-- windows (editor groups); <C-h/j/k/l>, <leader>-, <leader>| and <leader>wd already go through <C-w>
map("n", "<leader>w", "<C-w>", { desc = "Windows", remap = true }) -- which-key's proxy in the terminal
map("n", "<leader>wm", action("workbench.action.toggleMaximizeEditorGroup"), { desc = "Maximize Editor Group" })
map("n", "<leader>uZ", action("workbench.action.toggleMaximizeEditorGroup"), { desc = "Maximize Editor Group" })
map("n", "<C-Up>", action("workbench.action.increaseViewHeight"), { desc = "Increase Window Height" })
map("n", "<C-Down>", action("workbench.action.decreaseViewHeight"), { desc = "Decrease Window Height" })
map("n", "<C-Left>", action("workbench.action.decreaseViewWidth"), { desc = "Decrease Window Width" })
map("n", "<C-Right>", action("workbench.action.increaseViewWidth"), { desc = "Increase Window Width" })

-- git
map("n", "<leader>gg", action("workbench.view.scm"), { desc = "Source Control" })
map("n", "<leader>gG", action("workbench.view.scm"), { desc = "Source Control" })
map("n", "<leader>gs", action("workbench.view.scm"), { desc = "Git Status" })
map("n", "<leader>gl", action("workbench.scm.history.focus"), { desc = "Git Log (Graph)" })
map("n", "<leader>gL", action("workbench.scm.history.focus"), { desc = "Git Log (Graph)" })
map("n", "<leader>gf", action("timeline.focus"), { desc = "Git Current File History (Timeline)" })
map("n", "<leader>gb", action("git.blame.toggleEditorDecoration"), { desc = "Git Blame Line" })
map("n", "<leader>gd", action("git.openChange"), { desc = "Git Diff" })
map("n", "]h", action("workbench.action.editor.nextChange"), { desc = "Next Hunk" })
map("n", "[h", action("workbench.action.editor.previousChange"), { desc = "Prev Hunk" })
map(nx, "<leader>ghs", action("git.stageSelectedRanges"), { desc = "Stage Hunk" })
map(nx, "<leader>ghr", action("git.revertSelectedRanges"), { desc = "Reset Hunk" })
map(nx, "<leader>ghu", action("git.unstageSelectedRanges"), { desc = "Undo Stage Hunk" })
map("n", "<leader>ghS", action("git.stage"), { desc = "Stage Buffer" })
map("n", "<leader>ghR", action("git.clean"), { desc = "Reset Buffer" })
map("n", "<leader>ghp", action("editor.action.dirtydiff.next"), { desc = "Preview Hunk Inline" })
map("n", "<leader>ghb", action("git.blame.toggleEditorDecoration"), { desc = "Blame Line" })
map("n", "<leader>ghd", action("git.openChange"), { desc = "Diff This" })

-- ui
map("n", "<leader>uw", action("editor.action.toggleWordWrap"), { desc = "Toggle Wrap" })
map("n", "<leader>ul", toggle("editor.lineNumbers", "on", "off"), { desc = "Toggle Line Numbers" })
map("n", "<leader>uL", toggle("editor.lineNumbers", "relative", "on"), { desc = "Toggle Relative Number" })
map("n", "<leader>uh", toggle("editor.inlayHints.enabled", "on", "off"), { desc = "Toggle Inlay Hints" })
map("n", "<leader>uf", toggle("editor.formatOnSave", true, false), { desc = "Toggle Format on Save" })
map("n", "<leader>ud", toggle("problems.visibility", true, false), { desc = "Toggle Diagnostics" })
map("n", "<leader>ug", toggle("editor.guides.indentation", true, false), { desc = "Toggle Indent Guides" })
map("n", "<leader>ub", action("workbench.action.toggleLightDarkThemes"), { desc = "Toggle Dark Background" })
map("n", "<leader>uC", action("workbench.action.selectTheme"), { desc = "Colorschemes" })
map("n", "<leader>uz", action("workbench.action.toggleZenMode"), { desc = "Toggle Zen Mode" })
map("n", "<leader>ui", action("editor.action.inspectTMScopes"), { desc = "Inspect Pos" })
map("n", "<leader>n", action("notifications.showList"), { desc = "Notification History" })
map("n", "<leader>un", action("notifications.clearAll"), { desc = "Dismiss All Notifications" })

-- stylua: ignore end
