-- nvim-bufdel
-- By Olivier Roques
-- github.com/ojroques

-------------------- VARIABLES -----------------------------
local M = {}
local options = {
  next = 'tabs',  -- how to retrieve the next buffer
  quit = true,    -- quit Neovim when last buffer is closed
}

-------------------- PRIVATE -------------------------------
-- Switch to buffer 'buf' on each window from list 'windows'
local function switch_buffer(windows, buf)
  local cur_win = vim.fn.winnr()
  for _, winid in ipairs(windows) do
    vim.cmd(string.format('%d wincmd w', vim.fn.win_id2win(winid)))
    vim.cmd(string.format('buffer %d', buf))
  end
  vim.cmd(string.format('%d wincmd w', cur_win))
end

-- Select the next buffer to display
local function get_next_buf(buf)
  -- handle 'alternate' choice
  local alternate = vim.fn.bufnr('#')
  if options.next == 'alternate' and vim.fn.buflisted(alternate) == 1 then
    return alternate
  end
  -- handle custom function
  if type(options.next) == 'function' then
    return options.next()
  end
  -- build table mapping buffers to their actual position
  local buffers, buf_index = {}, 1
  for i, bufinfo in ipairs(vim.fn.getbufinfo({buflisted = 1})) do
    if buf == bufinfo.bufnr then
      buf_index = i
    end
    table.insert(buffers, bufinfo.bufnr)
  end
  -- select next buffer according to user choice
  if options.next == 'tabs' and buf_index == #buffers and #buffers > 1 then
    return buffers[#buffers - 1]
  end
  return buffers[buf_index % #buffers + 1]
end

-- Delete a buffer, ignoring changes if 'force' is set
local function delete_buffer(buf, force)
  if vim.fn.buflisted(buf) == 0 then
    return
  end
  -- retrieve buffer and delete it while preserving window layout
  local next_buf = get_next_buf(buf)
  local windows = vim.fn.getbufinfo(buf)[1].windows
  switch_buffer(windows, next_buf)
  -- force deletion of terminal buffers
  if force or vim.fn.getbufvar(buf, '&buftype') == 'terminal' then
    vim.cmd(string.format('bd! %d', buf))
  else
    vim.cmd(string.format('silent! confirm bd %d', buf))
  end
  -- revert buffer switches if deletion was cancelled
  if vim.fn.buflisted(buf) == 1 then
    switch_buffer(windows, buf)
  end
end

-------------------- PUBLIC --------------------------------
-- Delete a given buffer, ignoring changes if 'force' is set
function M.delete_buffer_expr(bufexpr, force)
  local current_buffer = vim.fn.bufnr()
  local windows_with_buffer = vim.fn.win_findbuf(current_buffer)
  local listed_buffers = vim.fn.getbufinfo({buflisted = 1})
  local tabpages = vim.fn.tabpagenr('$')

  -- Si plusieurs buffers sont ouverts dans la session
  if #listed_buffers > 1 then
    -- Si plusieurs fenêtres ont le même buffer, on ferme seulement la fenêtre active
    if #windows_with_buffer > 1 then
      vim.cmd('close')
    else
      -- Sinon, on change de buffer dans la même fenêtre
      vim.cmd('bprevious')
      vim.cmd('bd ' .. current_buffer)
    end
    return
  end

  -- Si un seul buffer est ouvert
  if #listed_buffers == 1 then
    -- Si ce buffer est affiché dans plusieurs fenêtres (splits)
    if #windows_with_buffer > 1 then
      vim.cmd('close')
      return
    else
      -- Si c'est le dernier buffer dans la session
      if tabpages < 2 then
        if options.quit then
          if force then
            vim.cmd('qall!')
          else
            vim.cmd('confirm qall')
          end
          return
        end
        -- Créer un buffer vide si aucune fermeture n'est autorisée
        vim.cmd('enew')
        vim.cmd('bp')
        return
      else
        -- Si ce n'est pas le dernier tab, juste fermer la fenêtre
        vim.cmd('close')
        return
      end
    end
  end

  -- Suppression du buffer spécifique si mentionné
  if bufexpr ~= nil then
    if tonumber(bufexpr) then
      delete_buffer(tonumber(bufexpr), force)
      return
    end
    bufexpr = string.gsub(bufexpr, [[^['"]+]], '')  -- Enlever les guillemets début/fin
    bufexpr = string.gsub(bufexpr, [[['"]+$]], '')
    delete_buffer(vim.fn.bufnr(bufexpr), force)
  end
end

-- Delete all listed buffers except current, ignoring changes if 'force' is set
function M.delete_buffer_others(force)
  for _, bufinfo in ipairs(vim.fn.getbufinfo({buflisted = 1})) do
    if bufinfo.bufnr ~= vim.fn.bufnr() then
      delete_buffer(bufinfo.bufnr, force)
    end
  end
end

-- Delete all listed buffers, ignoring changes if 'force' is set
function M.delete_buffer_all(force)
  M.delete_buffer_others(force)
  M.delete_buffer_expr(nil, force)
end

function M.setup(user_options)
  if user_options then
    options = vim.tbl_extend('force', options, user_options)
  end
end

------------------------------------------------------------
return M
