-- scripts/fix-typst-bg.lua
-- A background script launched by a Pandoc Lua filter to poll and patch
-- the index.typ file immediately after Pandoc writes it, before Quarto compiles it.

local typ_path = "index.typ"
local max_attempts = 50
local delay = "sleep 0.1" -- macOS/Linux sleep command

for i = 1, max_attempts do
    local f = io.open(typ_path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        
        -- Check if the show heading rule exists
        local pattern = "#show heading%.where%(level: 1%): it => %s*%b{}"
        if string.find(content, pattern) then
            local new_content, count = string.gsub(content, pattern, "/* Removed by fix-typst-bg.lua to avoid container pagebreak error in orange-book */")
            if count > 0 then
                local out = io.open(typ_path, "w")
                if out then
                    out:write(new_content)
                    out:close()
                    print("[fix-typst-bg.lua] Successfully patched index.typ on attempt " .. i)
                    return
                end
            end
        end
    end
    os.execute(delay)
end
print("[fix-typst-bg.lua] Failed to patch index.typ or show rule not found after maximum attempts.")
