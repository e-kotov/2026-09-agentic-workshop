-- scripts/trigger-fix.lua
-- A Pandoc Lua filter that starts the background patching script

function Pandoc(doc)
    -- Launch the background script in macOS/Linux
    os.execute("quarto run scripts/fix-typst-bg.lua &")
    return doc
end

local function process_abstract_block(el)
    local has_summary_title = false
    local summary_content = nil
    local teaser_content = nil
    
    for _, inline in ipairs(el.content) do
        if inline.t == "Span" and inline.classes:includes("summary-title") then
            has_summary_title = true
            summary_content = inline.content
        elseif inline.t == "Span" and inline.classes:includes("teaser-preview") then
            teaser_content = inline.content
        end
    end
    
    if has_summary_title then
        local blocks = {}
        if summary_content then
            -- Create a bold "Abstract" paragraph
            table.insert(blocks, pandoc.Para({ pandoc.Strong(summary_content) }))
        end
        if teaser_content then
            -- Create a separate paragraph for the teaser content
            table.insert(blocks, pandoc.Para(teaser_content))
        end
        return blocks
    end
    return nil
end

function Plain(el)
    return process_abstract_block(el)
end

function Para(el)
    return process_abstract_block(el)
end


