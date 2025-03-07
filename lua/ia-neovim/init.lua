local ia_neovim = {}

local function escape_for_json(s)
    s = s:gsub('\\', '\\\\\\')   -- Escape backslashes
    s = s:gsub('"', '\\"')     -- Escape double quotes
    s = s:gsub("'", "'\\''")
    s = s:gsub('\n', '\\n')    -- Escape newlines, if necessary
    s = s:gsub('\t', '\\t')    -- Escape tabs, if necessary
    s = s:gsub('\r', '\\r')
    s = s:gsub('\b', '\\b')
    s = s:gsub('\f', '\\f')

    return s
end

local delimiter = string.rep("─", 50)
local hdelimiter = "│ "
local tl = "╭"
local tr = ""
local bl = "╰"
local br = ""

local function remove_backticks_from_buffer(bufnr)
  -- Get all lines in the buffer along with their indices
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Iterate in reverse order over the buffer lines to avoid index shift issues when deleting lines
  for i = #lines, 1, -1 do
    local line = lines[i]

    -- Trim the line and check if it's made only of backticks
    if line:match("^%s*```%s*$") or line:match("^%s*```%w*%s*$") then
      -- Delete the line if it matches
      vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
    end
  end
end

local function highlight_bold_text(bufnr)
  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Iterate over each line and search for the pattern **...**
  for linenr, line in ipairs(lines) do
    -- Find the pattern
    local text_start, text_end = string.find(line, "%*%*(.-)%*%*")
    if text_start and text_end then
      -- Remove '**' from the text
      local new_line = line:sub(1, text_start - 1) .. line:sub(text_start + 2, text_end - 2) .. line:sub(text_end + 1)

      -- Set the modified line back to buffer
      vim.api.nvim_buf_set_lines(bufnr, linenr - 1, linenr, false, { new_line })

      -- Apply the highlight to the text found
      vim.api.nvim_set_hl(0, 'MyBoldGroup', { fg = "#8FBC8F", bold = true })
      vim.api.nvim_buf_add_highlight(bufnr, -1, "MyBoldGroup", linenr - 1, text_start - 1, text_end - 4)
    end
  end
end

local function remove_single_backticks(bufnr)
  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Iterate over each line and search for the pattern **...**
  for linenr, line in ipairs(lines) do
    -- Find the pattern
    local text_start, text_end = string.find(line, "`(.-)`")
    if text_start and text_end then
      -- Remove '**' from the text
      local new_line = line:sub(1, text_start - 1) .. line:sub(text_start + 2, text_end - 2) .. line:sub(text_end + 1)

      -- Set the modified line back to buffer
      vim.api.nvim_buf_set_lines(bufnr, linenr - 1, linenr, false, { new_line })
    end
  end
end

local function highlight_underline_text(bufnr)
  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Iterate over each line and search for the pattern starting with ###
  for linenr, line in ipairs(lines) do
    -- Find the pattern with a space after ###
    local text_start, text_end = string.find(line, "###%s*(.+)")
    if text_start and text_end then
      -- Remove '### ' from the text
      local new_line = line:sub(text_start + 4)

      -- Set the modified line back to buffer
      vim.api.nvim_buf_set_lines(bufnr, linenr - 1, linenr, false, { new_line })

      -- Apply the underline highlight to the text found
      vim.api.nvim_set_hl(0, 'MyUnderlineGroup', { fg = "#8FBC8F", underline = true })
      vim.api.nvim_buf_add_highlight(bufnr, -1, "MyUnderlineGroup", linenr - 1, 0, #new_line)
    end
  end
end

local function highlight_backticks(bufnr)
    local vim = vim
    
    -- Define a highlight group for italic text
    vim.api.nvim_set_hl(0, 'BacktickItalic', { fg = "#6a6a6a", italic = true })

    -- Retrieve all lines in the buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local inside_multiline_block = false
    local multiline_start = nil

    for line_nr, line in ipairs(lines) do
        local start_pos = 1

        -- Handle multiline backticks
        if inside_multiline_block then
            local end_backtick = line:find("```")
            if end_backtick then
                -- Highlight multiline block
                for i = multiline_start, line_nr - 1 do
                    -- Apply italic highlighting across lines
                    local line_length = #lines[i + 1]
                    vim.api.nvim_buf_add_highlight(bufnr, -1, 'BacktickItalic', i, 0, line_length)
                end
                -- Highlight final line within the backticks, if any text before the end backticks
                if end_backtick > 1 then
                    vim.api.nvim_buf_add_highlight(bufnr, -1, 'BacktickItalic', line_nr - 1, 0, end_backtick)
                end
                inside_multiline_block = false
            end
        else
            -- Search for single backticks `word` and multiline backticks ```
            while true do
                local start_backtick = line:find("`", start_pos)
                if not start_backtick then break end

                -- Check for multiline backticks
                if line:sub(start_backtick, start_backtick+2) == "```" then
                    -- Check if this line has the language specifier
                    inside_multiline_block = true
                    multiline_start = line_nr
                    break
                end

                -- Check if the backtick is escaped
                if start_backtick > 1 and line:sub(start_backtick - 1, start_backtick - 1) == "\\" then
                    start_pos = start_backtick + 1
                else
                    local end_backtick = line:find("`", start_backtick + 1)
                    while end_backtick and line:sub(end_backtick - 1, end_backtick - 1) == "\\" do
                        -- Skip escaped backtick
                        end_backtick = line:find("`", end_backtick + 1)
                    end

                    if not end_backtick then break end

                    -- Highlight single line backtick content
                    vim.api.nvim_buf_add_highlight(
                        bufnr, 
                        -1, 
                        'BacktickItalic', 
                        line_nr - 1, 
                        start_backtick, 
                        end_backtick
                    )

                    -- Move start position for next search
                    start_pos = end_backtick + 1
                end
            end
        end
    end
end

local function append_lines_and_move_cursor(response)
    local vim = vim  -- Make sure to use the Neovim 'vim' global

    -- Access the current buffer
    local buf = vim.api.nvim_get_current_buf()

    -- Create a highlight group for soft green text
    vim.api.nvim_exec([[
        highlight SoftGreen guifg=#8FBC8F
    ]], false)

    -- Define the namespace for virtual text to allow for easy management or clearing
    local ns_id = vim.api.nvim_create_namespace("pipes_ns")

    -- Split the response into lines, add " " characters at the beginning and the end of each line
    local response_lines = vim.split(response, "\n")
    for i, line in ipairs(response_lines) do
        response_lines[i] = "  " .. line
    end

    local start_line = vim.api.nvim_buf_line_count(buf) + 1

    -- Append the modified response lines
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {""})
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, response_lines)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {"", ""})

    -- markdown style
    highlight_backticks(buf)
    highlight_bold_text(buf)
    highlight_underline_text(buf)

    -- Highlight response lines
    for i = start_line, start_line + #response_lines + 1 do
        vim.api.nvim_buf_add_highlight(buf, -1, "SoftGreen", i, 0, -1)
    end

    remove_backticks_from_buffer(buf)

    local last_line = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(0, {last_line, 0})
end

function Test()
   local buf = vim.api.nvim_get_current_buf()

   -- List of lines to display
   local lines = {
       "  Hello World",
       "  Another Line",
       "  Yet Another Line"
   }

   -- Set lines in the buffer
   local start_line = vim.api.nvim_buf_line_count(buf)
   vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
   local last_line = vim.api.nvim_buf_line_count(buf)

   -- Adding virtual text (pipe) before each line
   for i = 0, #lines - 1 do
       vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace('pipes_namespace'), i+start_line, 0, {
           virt_text = { { hdelimiter, "NonText" } },
           virt_text_pos = 'overlay', -- Positioning the virt_text at the beginning
       })
   end
   vim.api.nvim_win_set_cursor(0, {last_line, 0})
end

-- Retrieves all buffers opened and return an array of objects with file name and their content
function ia_neovim.retrieveBuffersContent()
  local buffers = vim.api.nvim_list_bufs()
  local buffers_content = {}

  for _, bufnr in ipairs(buffers) do
    local buffer_name = vim.api.nvim_buf_get_name(bufnr)
    local buffer_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    table.insert(buffers_content, {
      name = buffer_name,
      content = buffer_content
    })
  end

  return buffers_content
end

function ia_neovim.AzureFunctionCall()
  vim.notify("Generatig...", vim.log.levels.INFO)
  -- Get the text of the current buffer
  local buffer_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local complete_text = table.concat(buffer_content, "\n")
  local full_text = escape_for_json(complete_text)

  local encrypted_data = ia_neovim.encrypt(full_text)
  
  -- Replace `your_function_url_here` with your actual Azure Function endpoint
  local azure_function_url = os.getenv("IA_NEOVIM_FUNC_URL")
  local azure_function_key = os.getenv("IA_NEOVIM_FUNC_KEY")
  
  local body = {
    question = encrypted_data,
    files = ia_neovim.retrieveBuffersContent()
  }

  -- store body in a tmp file
  local json_data = vim.fn.json_encode(body)

  -- write the json data to a temp file
  local tmp_file = vim.fn.tempname()
  local file = io.open(tmp_file, "w")
  file:write(json_data)
  file:close()

  -- Prepare the curl curl_command
  local curl_command = string.format(
    'curl -s -X POST -H "Content-Type: application/json" --data-binary @%s %s?code=%s',
    tmp_file,
    azure_function_url,
    azure_function_key
  )

  vim.notify("Printing...", vim.log.levels.INFO)

  -- Call the Azure function using curl
  local response = vim.fn.system(curl_command)

  -- Open a new line and insert the response
  append_lines_and_move_cursor(response)

  -- print silently
  vim.notify("Done.", vim.log.levels.INFO)
end

function ia_neovim.getKey()
  -- Replace our_function_url_her with your actual Azure Function endpoint
  local azure_function_url = os.getenv("IA_KEY_NEOVIM_FUNC_URL")
  local azure_function_key = os.getenv("IA_KEY_NEOVIM_FUNC_KEY")

  -- Prepare the curl command, just GET
  local curl_command = string.format(
    'curl -s -X GET %s?code=%s',
    azure_function_url,
    azure_function_key
  )

  -- collect the response in a string
  local response = vim.fn.system(curl_command)
  print(response)

  return response
end

local function base64_encode(data)
  local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x) 
    local r,b='',x:byte()
    for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
    return r;
  end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c=0
    for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
    return b:sub(c+1,c+1)
  end)..({ '', '==', '=' })[#data%3+1])
end

function ia_neovim.encrypt(body)
    local key = ia_neovim.getKey()
    local encoded = base64_encode(body)
    return encoded
end

vim.api.nvim_set_keymap('n', '<leader>ia', ':lua AzureFunctionCall()<CR>', { noremap = true, silent = true })

return ia_neovim
