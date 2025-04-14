local app_name, script_dir = ...

local M = {}

function M.buildSpecialFields(libGUI, panel, Page, y, updateValueChange)
    local num_col = 3
    local row_h = 35
    local col1_w = 160
    local col_w  = (LCD_W-col1_w)/num_col-1
    local col_w2 = (LCD_W-col1_w)/num_col

    -- col headers
    local col_name_1 = Page.labels[7].t  .. " " .. Page.labels[8].t
    local col_name_2 = Page.labels[9].t  .. " " .. Page.labels[10].t
    local col_name_3 = Page.labels[11].t .. " " .. Page.labels[12].t
    libGUI.newControl.ctl_title(panel, nil, {x=0,y=y, w=col1_w, h=30, text1_x=5, bg_color=GREY, text1=" "})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+0*(col_w2), y=y, w=col_w, h=30, text1_x="CENTER", bg_color=GREY, text1=col_name_1})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+1*(col_w2), y=y, w=col_w, h=30, text1_x="CENTER", bg_color=GREY, text1=col_name_2})
    libGUI.newControl.ctl_title(panel, nil, {x=col1_w+1+2*(col_w2), y=y, w=col_w, h=30, text1_x="CENTER", bg_color=GREY, text1=col_name_3})

    y = y + 30
    -- line names
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+0*row_h, w=col1_w, h=row_h, bg_color=RED,    text1_x=10, text1="ROLL"})
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+1*row_h, w=col1_w, h=row_h, bg_color=GREEN,  text1_x=10, text1="PITCH"})
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+2*row_h, w=col1_w, h=row_h, bg_color=BLUE,   text1_x=10, text1="YAW"})
    libGUI.newControl.ctl_title(panel, nil, {x=0, y=y+3*row_h, w=col1_w, h=row_h, bg_color=ORANGE, text1_x=10, text1="COLLECTIVE"})

    -- values
    for col=1, 3 do
        for row=1, 4 do
            local x = col1_w+1+(col-1)*(col_w2)
            local y = y + (row-1)*row_h
            local i = (col-1)*4 + row
            local f = Page.fields[i]
            local scale = f.data.scale or 1
            local mult = f.data.mult or 1
            local min = f.data.min / (scale or 1)
            local max = f.data.max / (scale or 1)
            local val  = (f.data.value or 0) / (scale or 1)*(mult or 1)
            if val > 1 then
                val = math.floor(val)
            end
            local hlp1 = (row==1 and "ROLL") or (row==2 and "PITCH") or (row==3 and "YAW") or (row==4 and "COLL")
            local hlp2 = (col==1 and col_name_1) or (col==2 and col_name_2) or (col==3 and col_name_3)

            libGUI.newControl.ctl_rf2_button_number(panel,  "rates-"..col.."-"..row, {
                x=x+1, y=y+1, w=col_w-2, h=row_h-2,
                min=min, max=max,
                steps= (1/(scale or 1))*(mult or 1),
                value=val,
                units="",
                text=nil,
                help=hlp1 .. "  -  " .. hlp2,
                onValueUpdated=function(ctl, newVal)
                    updateValueChange(i, newVal)
                end
            })
        end
    end

    -- libGUI.newControl.ctl_title(panel, nil,
    --     {x=0, y=230, w=LCD_W, h=25, text1="Advance", bg_color=panel.colors.topbar.bg, txt_color=panel.colors.topbar.txt})

    -- return 13,235 -- firstRegularField, last_y
    return 1000,235 -- firstRegularField, last_y
end

return M
