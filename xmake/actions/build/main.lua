--!The Automatic Cross-platform Build Tool
-- 
-- XMake is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 2.1 of the License, or
-- (at your option) any later version.
-- 
-- XMake is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public License
-- along with XMake; 
-- If not, see <a href="http://www.gnu.org/licenses/"> http://www.gnu.org/licenses/</a>
-- 
-- Copyright (C) 2015 - 2016, ruki All rights reserved.
--
-- @author      ruki
-- @file        main.lua
--

-- imports
import("core.base.option")
import("core.project.task")
import("core.project.config")
import("core.project.project")
import("core.project.cache")
import("core.platform.platform")
import("core.tool.tool")
import("builder")

-- project files(xmake.lua) have been changed?
function _project_changed(targetname)

    -- get the current mtimes 
    local mtimes = project.mtimes()

    -- get the previous mtimes 
    local changed = false
    local mtimes_prev = cache.get("mtimes")
    if mtimes_prev then 

        -- check for all project files
        for file, mtime in pairs(mtimes) do

            -- modified? reconfig and rebuild it
            local mtime_prev = mtimes_prev[file]
            if not mtime_prev or mtime > mtime_prev then
                changed = true
                break
            end
        end
    end

    -- update mtimes
    cache.set("mtimes", mtimes)

    -- changed?
    return changed
end

-- main
function main()

    -- check xmake.lua
    if not os.isfile(project.file()) then
        raise("xmake.lua not found!")
    end

    -- get the target name
    local targetname = option.get("target")

    -- load project configure
    config.load(targetname)

    -- enter cache scope: build
    cache.enter("local.build")

    -- host changed? 
    if config.host() ~= os.host() then

        -- reinit config
        config.init()

        -- reconfig it
        task.run("config", {target = targetname, clean = true})

    -- project changed? 
    elseif _project_changed(targetname) then
        
        -- reconfig it
        task.run("config", {target = targetname})
    end

    -- load platform
    platform.load(config.plat())

    -- load project
    project.load()

    -- rebuild?
    if option.get("rebuild") or cache.get("rebuild") then
        
        -- clean it first
        task.run("clean", {target = targetname})

        -- reset state
        cache.set("rebuild", nil)
    end

    -- flush cache to file
    cache.flush()

    -- enter project directory
    os.cd(project.directory())

    -- build it
    try
    {
        function ()

            -- make 
            builder.make(targetname or "all")
        
        end,

        catch 
        {
            function (errors)

                -- failed
                if errors then
                    raise(errors)
                else
                    raise("build target: %s failed!", targetname)
                end
            end
        }
    }

    -- leave project directory
    os.cd("-")

    -- trace
    print("build ok!")

end