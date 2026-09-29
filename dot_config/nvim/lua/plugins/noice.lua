-- noice 自带的 hover 用 buf_request 逐个渲染每个 LSP 的响应，后返回的会覆盖先返回的。
-- 这里关闭 noice 的 hover 替换，改用自己的实现：先收齐所有 LSP 的结果并合并，
-- 再交给 noice 渲染，保留 noice 的窗口样式与 <C-f>/<C-b> 滚动。

local function hover()
  local Docs = require("noice.lsp.docs")
  local Format = require("noice.lsp.format")
  local bufnr = vim.api.nvim_get_current_buf()

  local params = function(client)
    return vim.lsp.util.make_position_params(0, client.offset_encoding)
  end

  vim.lsp.buf_request_all(bufnr, "textDocument/hover", params, function(results)
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end

    local items = {} ---@type {name: string, lines: string[]}[]
    for client_id, resp in pairs(results) do
      local result = resp.result
      if resp.err then
        vim.lsp.log.error(resp.err.code, resp.err.message)
      elseif result and result.contents then
        local contents = result.contents
        local lines
        if type(contents) == "table" and contents.kind == "plaintext" then
          lines = { "```", contents.value or "", "```" }
        else
          lines = vim.lsp.util.convert_input_to_markdown_lines(contents)
        end
        if #vim.trim(table.concat(lines, "\n")) > 0 then
          local client = vim.lsp.get_client_by_id(client_id)
          items[#items + 1] = { name = client and client.name or tostring(client_id), lines = lines }
        end
      end
    end

    if #items == 0 then
      vim.notify("No information available")
      return
    end
    table.sort(items, function(a, b)
      return a.name < b.name
    end)

    local parts = {} ---@type string[]
    for i, item in ipairs(items) do
      if i > 1 then
        parts[#parts + 1] = "---"
      end
      if #items > 1 then
        parts[#parts + 1] = "# " .. item.name
      end
      vim.list_extend(parts, item.lines)
    end

    local message = Docs.get("hover")
    if not message:focus() then
      Format.format(message, table.concat(parts, "\n"), { ft = vim.bo[bufnr].filetype })
      Docs.show(message)
    end
  end)
end

return {
  "folke/noice.nvim",
  opts = {
    lsp = {
      hover = { enabled = false }, -- 不让 noice 替换 vim.lsp.buf.hover
    },
  },
  init = function()
    vim.lsp.buf.hover = hover
  end,
}
