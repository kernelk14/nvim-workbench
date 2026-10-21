-- The editor pane, it simply shows the buffer that was being edited.

return {
  name = "editor",
  title = "",
  icon = "",

  --- The editor shows the buffer captured when the workbench opened.
  ---@param ctx table
  ---@return integer?
  buffer = function(ctx)
    if ctx.captured_buf and vim.api.nvim_buf_is_valid(ctx.captured_buf) then
      return ctx.captured_buf
    end
    return nil
  end,

  --- The editor keeps the normal window options.
  ---@param ctx table
  attach = function(ctx) end,
}
