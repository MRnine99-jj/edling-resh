local SkillAddModule = {}
SkillAddModule.Internal = {}
SkillAddModule.Internal.References = {}
SkillAddModule.Skill = {}
SkillAddModule.Decoration = {}
SkillAddModule.Strings = {}
SkillAddModule.Online = {}
SkillAddModule.Initialized = false
SkillAddModule.HighestKnownSkill = 131
SkillAddModule.CurrentDecoOffset = 150
SkillAddModule.safeReplacement = 95
SkillAddModule.Language = 1

SkillAddModule.Strings.Handled = {}

local TranslationIDs = {}
    TranslationIDs[0] = "JP"
    TranslationIDs[1] = "EN"
    TranslationIDs[2] = "FR"
    TranslationIDs[3] = "IT"
    TranslationIDs[4] = "DE"
    TranslationIDs[5] = "ES"
    TranslationIDs[6] = "RU"
    TranslationIDs[7] = "PL"
    TranslationIDs[10] = "PT"
    TranslationIDs[11] = "KR"
    TranslationIDs[12] = "TC"
    TranslationIDs[13] = "SC"
    TranslationIDs[21] = "AR"

local AffectedArmorIds = {}

local foundSkill = true
re.on_frame(function()
    --log.debug(tostring(SkillAddModule.Initialized) .. " : " .. tostring(foundSkill))
    if SkillAddModule.Initialized == false and foundSkill == true then
        log.debug("Iterated")
        foundSkill = false
        local skillData = sdk.get_managed_singleton("snow.data.SkillDataManager")
        if skillData then
            skillData = skillData:get_field("_PlEquipSkillModule")
        end
        local dataList
        if skillData then
            dataList = skillData:get_field("_BaseUserData"):get_field("_Param")
        end
        local optionsManager = sdk.get_managed_singleton("snow.gui.OptionManager")
        if optionsManager then
            SkillAddModule.Language = optionsManager:call("getDisplayLanguage()")
        end
        local canArmorEdit = 
        pcall(function()
            local armorData = sdk.get_managed_singleton("snow.data.ContentsIdDataManager"):get_field("_PlArmorIdDataModule")
            local dataList = armorData:call("get_ArmorSeriesDataList")
            dataList:call("get_Item", 1):call("updateSeriesSkillList")
        end)
        if dataList and canArmorEdit and optionsManager then
            if not pcall(function() dataList:get_elements() end) then
                local newArray = sdk.create_managed_array("snow.data.PlEquipSkillBaseUserData.Param", HighestKnownSkill):add_ref()
                for i = 0, SkillAddModule.HighestKnownSkill - 1 do
                    if pcall(function() dataList:get_element(i):get_field("_Id") end) then
                        newArray:call("set_Item", i, dataList:get_element(i))
                    else
                    end
                end
                --skillData:get_field("_BaseUserData"):get_field("_Param"):force_release()
                skillData:get_field("_BaseUserData"):set_field("_Param", newArray)
            end
            local UserSkills = {}
    
            for x, skill in ipairs (dataList:get_elements()) do
                if skill then
                    if skill:get_field("_WorthPointList") == 4812 then
                        table.insert(UserSkills, {x-1, skill})
                        log.debug("Found UserCreatedSkill " .. skill:get_field("_Id"))
                    end
                end
            end
    
            if #UserSkills > 0 then
                local newArray = sdk.create_managed_array("snow.data.PlEquipSkillBaseUserData.Param", #dataList:get_elements()-#UserSkills):add_ref()
                local freshList = skillData:get_field("_BaseUserData"):get_field("_Param")
                local spottedSkills = 0
                for i = 0,freshList:call("get_Length")-1 do
                    local currentTag = false
                    for _,v in pairs(UserSkills) do
                        if v[1] == i then
                            currentTag = true
                        end
                    end
                    if currentTag == false then
                        newArray:call("set_Item",i - spottedSkills,freshList[i])
                    else
                        --freshList[i]:force_release()
                        spottedSkills = spottedSkills + 1
                    end
                end
                --skillData:get_field("_BaseUserData"):get_field("_Param"):force_release()
                skillData:get_field("_BaseUserData"):set_field("_Param", newArray)
            end

            --[[
            local Smithy = sdk.get_managed_singleton("snow.data.FacilityDataManager")
            if Smithy then
                Smithy = Smithy:get_field("_Smithy"):get_field("_Function"):call("get__DecorationsProductFunc")
                local newArray = Smithy:call("get_AllProductList"):call("ToArray")
                for i = 0, Smithy:call("get_AllProductList"):call("get_Count")-1 do
                    local deco = Smithy:call("get_AllProductList"):call("get_Item", i)
                    if deco then
                        if i > 0x64 then
                            log.debug("Force released " .. i)
                            Smithy:call("get_AllProductList"):call("RemoveAt", i)
                        end
                    end
                end
                
            else
                foundSkill = true
                log.debug("no Smithy")
            end
            ]]
            SkillAddModule.Initialized = true
        else
            foundSkill = true
        end
    end
end)

function SkillAddModule.Online.ProtectStatus(retval)
    local equipStatus = sdk.to_managed_object(retval)
    log.debug("Handling send request : Status")
    for i,skillId in pairs(equipStatus:get_field("EquipSkillType"):get_elements()) do
        if skillId:get_field("value__") > SkillAddModule.HighestKnownSkill then
            equipStatus:get_field("EquipSkillType"):call("set_Item", i - 1, SkillAddModule.safeReplacement)
            equipStatus:get_field("SkillLv"):call("set_Item", i - 1, 1)
        end
    end
    return equipStatus
end

function SkillAddModule.Online.ProtectArmor(retval)
    local armorParam = sdk.to_managed_object(retval)
    log.debug("Handling send request : Armor")
    for i = 0, armorParam:call("get_Count")-1 do
        armor = armorParam:call("get_Item", i)
        for x, skill in pairs(armor:get_field("SkillIdList"):get_elements()) do
            if skill:get_field("value__") > SkillAddModule.HighestKnownSkill then
                armor:get_field("SkillIdList"):call("set_Item", x-1, 0)
            end
        end
    end
    return armorParam
end

-- The following three functions handle online play.
local IsForSend = false
-- This hook toggles a flag for whenever the game tries to send status parameters.
sdk.hook(
    sdk.find_type_definition("snow.gui.EquipStatusParamManager"):get_method("sendMyParam"),
    function(args)
        log.debug("Is For Sending")
        IsForSend = true
    end,
    function(retval)
        IsForSend = false
    end
)

-- The following function handles online, and prevents the game from sending skills that are higher than they should be to the gui. This one's for armor pieces.
sdk.hook(
    sdk.find_type_definition("snow.gui.define.EquipDetailParamShortcut"):get_method("createEquipStatusParam(System.Boolean, System.Boolean)"),
    function (args)
    end,
    function(retval)
        if not IsForSend then return retval end
        equipStatus = SkillAddModule.Online.ProtectStatus(retval)
        retval = sdk.to_ptr(equipStatus)
    return retval end
)

-- The following function handles online, and prevents the game from sending skills that are higher than they should be to the gui. This one's for the skill summary.
sdk.hook(
    sdk.find_type_definition("snow.gui.define.EquipDetailParamShortcut"):get_method("createArmorDataParam"),
    function (args)
    end,
    function(retval)
        if not IsForSend then return retval end
        log.debug("Handling send request")
        armorParam = SkillAddModule.Online.ProtectArmor(retval)
        retval = sdk.to_ptr(armorParam)
    return retval end
)

function SkillAddModule.Strings.PreIntArgString(args)
    return sdk.to_int64(args[2])
end
function SkillAddModule.Strings.PostIntArgString(Orig, Replace, String, retval)
    if Orig == Replace then
        retval = sdk.to_ptr(sdk.create_managed_string(String))
    end
    return retval
end

function SkillAddModule.Strings.PreLevelArgString(args)
    return sdk.to_int64(args[2]), sdk.to_int64(args[3])
end
function SkillAddModule.Strings.PostLevelArgString(Orig, Replace, level, Strings, retval)
    if Orig == Replace then
        for i,v in pairs(Strings) do
            if level == i-1 then
                retval = sdk.to_ptr(sdk.create_managed_string(v))
            end
        end
    end
    return retval
end

function SkillAddModule.Strings.PreDataArgString(args)
    return sdk.to_managed_object(args[2]):call("get_Id")
end

function SkillAddModule.Strings.AddHandled(SkillId, Name, Explain, LevelExplain, ReplacementDecoId, DecoName, DecoExplain)
    if SkillAddModule.Language ~= 1 and TranslationIDs[SkillAddModule.Language] then
        local translation = json.load_file("SkillModuleTranslations/"..Name.."_"..TranslationIDs[SkillAddModule.Language]..".json")
        if translation then
            Name = translation.Name and translation.Name or Name
            Explain = translation.Explain and translation.Explain or Explain
            for i,v in pairs(LevelExplain) do
                if translation.LevelExplain[i] then
                    LevelExplain[i] = translation.LevelExplain[i]
                end
            end
            DecoName = translation.DecoName and translation.DecoName or DecoName
            DecoExplain = translation.DecoExplain and translation.DecoExplain or DecoExplain
        end
    end
    table.insert(SkillAddModule.Strings.Handled, {SkillId, Name, Explain, LevelExplain, ReplacementDecoId, DecoName, DecoExplain})
end

function SkillAddModule.Internal.HandleDecos(equipSkillId, retval, type)
    for i,v in pairs(SkillAddModule.Strings.Handled) do
        if equipSkillId == v[1] then
            retval = sdk.to_ptr(sdk.create_managed_string(v[type]))
        end
    end
    return retval
end

function SkillAddModule.Internal.HandleLabels(equipSkillId, retval, type, equipSkillLv)
    local Skill = (type < 5)
    local usedId = (Skill and 1 or 5)

    for i,v in pairs(SkillAddModule.Strings.Handled) do
        if equipSkillId == v[usedId]then
            if type == 4 then
                retval = sdk.to_ptr(sdk.create_managed_string(v[type][equipSkillLv+1]))
            else
                retval = sdk.to_ptr(sdk.create_managed_string(v[type]))
            end
            return retval
        end
    end
    return retval
end

-- This function handles the name of your skill
local equipSkillId = -1
local equipSkillLv = -1
sdk.hook(
    sdk.find_type_definition("snow.data.DataShortcut"):get_method("getName(snow.data.DataDef.PlEquipSkillId)"),
    function (args) 
        equipSkillId = SkillAddModule.Strings.PreIntArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 2)
    return retval end
)
-- This one handles its explanation
sdk.hook(
    sdk.find_type_definition("snow.data.DataShortcut"):get_method("getExplain(snow.data.DataDef.PlEquipSkillId)"),
    function (args) 
        equipSkillId = SkillAddModule.Strings.PreIntArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 3)
    return retval end
)
-- This one also handles its explanation for certain cases
sdk.hook(
    sdk.find_type_definition("snow.data.PlEquipSkillBaseData"):get_method("get_Explain"),
    function (args) 
        equipSkillId = SkillAddModule.Strings.PreIntArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 3)
    return retval end
)
-- This one handles the per-level explanations
sdk.hook(
    sdk.find_type_definition("snow.data.DataShortcut"):get_method("getDetailTxt"),
    function (args) 
        equipSkillId, equipSkillLv = SkillAddModule.Strings.PreLevelArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 4, equipSkillLv)
    return retval end
)



-- This one handles the name of the decoration
sdk.hook(
    sdk.find_type_definition("snow.data.DecorationBaseData"):get_method("get_Name"),
    function (args) 
        equipSkillId = SkillAddModule.Strings.PreIntArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 6)
    return retval end
)

-- This one handles the description of the decoration
sdk.hook(
    sdk.find_type_definition("snow.data.DecorationBaseData"):get_method("get_Explain"),
    function (args) 
        equipSkillId = SkillAddModule.Strings.PreIntArgString(args)
    end,
    function (retval)
        retval = SkillAddModule.Internal.HandleLabels(equipSkillId, retval, 7)
    return retval end
)


function SkillAddModule.Decoration.createCraftingData(ReplacementDecoId, DecoRecipe, ItemFlag, EmFlag, ProgressFlag)
    local decoData = sdk.get_managed_singleton("snow.data.ContentsIdDataManager"):get_field("_PlDecorationsIdDataModule")
    local dataList = decoData:call("get_ProductRecipeDataList")    
    local baseRecipe = dataList:call("get_Item", ReplacementDecoId)

    local param = baseRecipe:get_field("_PlDecorationProductUserDataParam")
    
    param:set_field("_Id", ReplacementDecoId)
    param:set_field("_ItemFlag", ItemFlag)
    param:set_field("_EnemyFlag", EmFlag)
    param:set_field("_ProgressFlag", ProgressFlag)

    local itemIdList = param:get_field("_ItemIdList")
    local itemNuList = param:get_field("_ItemNumList")
    for i = 1,4 do
        itemIdList:call("set_Item", i-1, DecoRecipe[i][1])
        itemNuList:call("set_Item", i-1, DecoRecipe[i][2])
    end

    return baseRecipe
end

function SkillAddModule.Decoration.Replace(ReplacementDecoId, skillColor, DecoLevel, DecoRarity,DecoSort, SkillId, SkillBaseData, useOffset)
    useOffset = false
    local decoData = sdk.get_managed_singleton("snow.data.ContentsIdDataManager"):get_field("_PlDecorationsIdDataModule")
    local dataList = decoData:call("get_BaseDataList")
    local baseDeco = dataList:call("get_Item", ReplacementDecoId)
    if baseDeco and baseDeco:get_field("_Param") then
        baseDeco:get_field("_Param"):set_field("_IconColor", skillColor)
        baseDeco:get_field("_Param"):set_field("_DecorationLv", DecoLevel)
        baseDeco:get_field("_Param"):set_field("_Rare", DecoRarity)
        baseDeco:get_field("_Param"):set_field("_SortId", DecoSort)
        baseDeco:get_field("_Param"):get_field("_SkillIdList"):call("set_Item",0, SkillId)
        baseDeco:call("get_SkillIdList"):call("set_Item",0, SkillId)
        baseDeco:call("get_SkillDataList"):call("get_Item",0):call("set_EquipSkillId", SkillId)
        baseDeco:call("get_SkillDataList"):call("get_Item",0):call("set_BaseData", SkillBaseData)
    else 
        local DecoRecipe = {
            {67108864, 0},
            {67108864, 0},
            {67108864, 0},
            {67108864, 0},
        }
        ReplacementDecoId = useOffset and SkillAddModule.CurrentDecoOffset or ReplacementDecoId
        if useOffset then
            SkillAddModule.Decoration.AddDeco(SkillAddModule.CurrentDecoOffset, DecoRarity, DecoSort, skillColor, DecoLevel, {{SkillId,1}}, 2000, DecoRecipe, 0,0,0)
            SkillAddModule.CurrentDecoOffset = SkillAddModule.CurrentDecoOffset + 1
        else
            SkillAddModule.Decoration.AddDeco(ReplacementDecoId, DecoRarity, DecoSort, skillColor, DecoLevel, {{SkillId,1}}, 2000, DecoRecipe, 0,0,0)
        end
    end
    return ReplacementDecoId
end

function SkillAddModule.Skill.AssignArmorData(ArmorEditList, SkillId)
    local armorData = sdk.get_managed_singleton("snow.data.ContentsIdDataManager"):get_field("_PlArmorIdDataModule")
    local dataList = armorData:call("get_ArmorSeriesDataList")
    for ArmorIndex,EditArmor in pairs (ArmorEditList) do
        local SaveData = {ArmorIndex, {}}
        local data = dataList:get_element(ArmorIndex)
        --local func = "get_".. (EditArmor[1] and "Ex" or "") .."ArmorIdList"
        local func = "get_ArmorIdList"
        local pieces = data:call(func)

        for i,v in pairs(EditArmor[2]) do
            if v[1] == true then
                local pieceId = pieces:call("get_Item", i-1)
                table.insert(SaveData[2], pieceId)
                local pieceBaseData = armorData:call("getBaseData", pieceId)
                local piecePlainData = armorData:call("getPlainArmorData", pieceId)
                local skillDataList = pieceBaseData:call("get_AllSkillDataList")
                local firstAvailableSlot = 4
                for i = 0, skillDataList:call("get_Count")-1 do
                    if skillDataList:call("get_Item", i):call("get_EquipSkillId") == 0 then
                        firstAvailableSlot = i
                        break
                    end
                end
                local skillData = skillDataList:call("get_Item", firstAvailableSlot)
                skillData:call("set_EquipSkillId", SkillId)
                for i = 1, v[2] do
                    skillData:call("get_LvList"):call("set_Item", i, 1)
                end
                piecePlainData:call("updateSkillDataList")
            end
        end
        table.insert(AffectedArmorIds, SaveData)
        data:call("updateSeriesSkillList")
    end
end

function SkillAddModule.Internal.createUserData(MaxLevel, IconColor)
    local skillData = sdk.get_managed_singleton("snow.data.SkillDataManager"):get_field("_PlEquipSkillModule")
    if not skillData then return end
    local dataList = skillData:get_field("_BaseUserData"):get_field("_Param")
    if not dataList then return end
    local param = sdk.create_instance("snow.data.PlEquipSkillBaseUserData.Param")

    local ChosenId = #dataList:get_elements() + 1

    param:set_field("_Id", ChosenId)
    param:set_field("_MaxLevel", MaxLevel)
    param:set_field("_IconColor", IconColor)
    param:set_field("_WorthPointList", 4812)

    local skillParam = param:add_ref()

    local newArray = sdk.create_managed_array("snow.data.PlEquipSkillBaseUserData.Param", #dataList:get_elements()+1):add_ref()
    local freshList = skillData:get_field("_BaseUserData"):get_field("_Param")
    for i = 0,freshList:call("get_Length")-1 do
        if freshList[i] then
            newArray:call("set_Item",i,freshList[i])
        end
    end
    newArray:call("set_Item",#dataList:get_elements(), skillParam)
    skillData:get_field("_BaseUserData"):set_field("_Param", newArray)
    return skillParam, ChosenId
end

function SkillAddModule.Internal.createBaseData(skillId, skillParam)
    local SkillData = sdk.get_managed_singleton("snow.data.SkillDataManager"):get_field("_PlEquipSkillModule")
    local dataList = SkillData:call("get_BaseDataList")
    local newArray = sdk.create_managed_array("snow.data.DecorationBaseData",#dataList:get_elements()+1)
    
    local baseSkill = sdk.create_instance("snow.data.PlEquipSkillBaseData", true)
    local skillRef = baseSkill:add_ref()

    baseSkill:set_field("_Param", skillParam)

    local freshList = SkillData:call("get_BaseDataList")
    for i = 0,freshList:call("get_Count")-1 do
        if freshList[i] then
            newArray:call("set_Item",i,freshList[i])
        end
    end
    newArray:call("set_Item", skillId, baseSkill)
    SkillData:call("set_BaseDataList", newArray)
    return skillRef
end

function SkillAddModule.Skill.AddSkill(MaxLevel, IconColor)
    local param, SkillId = SkillAddModule.Internal.createUserData(MaxLevel, IconColor)
    local baseSkill = SkillAddModule.Internal.createBaseData(SkillId, param)
    return param, baseSkill, SkillId
end


function SkillAddModule.Internal.AddToArray(Array, ArrayType, Item, Location)
    if not Location then Location = -1 end
    length = Array:call("get_Count") + 1 > Location and Array:call("get_Count") + 1 or Location + 1
    local newArray = sdk.create_managed_array(ArrayType, length)

    for i = 0, Array:call("get_Count") - 1 do
        newArray:call("set_Item", i, Array:call("get_Item", i))
    end

    newArray:call("set_Item", (Location == -1 and Array:call("get_Count") or Location), Item)

    return newArray
end

function SkillAddModule.Internal.CreateUserDeco(PrivateId, rare, SortId, Color, Lv, SkillIds, Price)
    local TotalSkill = 2

    local Deco = sdk.create_instance("snow.data.DecorationsBaseUserData.Param")
    Deco:set_field("_Id", PrivateId)
    Deco:set_field("_SortId", SortId)
    Deco:set_field("_Rare", rare)
    Deco:set_field("_IconColor", Color)
    Deco:set_field("_DecorationLv", Lv)
    Deco:set_field("_BasePrice", Price)
    
    local SkillIdList = sdk.create_managed_array("snow.data.DataDef.PlEquipSkillId", TotalSkill)
    local SkillLvList = sdk.create_managed_array("System.Int32", TotalSkill)
    for index, skill in pairs(SkillIds) do
        SkillIdList:call("set_Item", index - 1, skill[1])
        SkillLvList:call("set_Item", index - 1, skill[2])
    end
    SkillIdList:call("set_Item", 1, 0)
    SkillLvList:call("set_Item", 1, 0)

    local SkillIdParam = SkillIdList:add_ref()
    table.insert(SkillAddModule.Internal.References, SkillIdParam)
    local SkillLvParam = SkillLvList:add_ref()
    table.insert(SkillAddModule.Internal.References, SkillLvParam)

    Deco:set_field("_SkillIdList", SkillIdParam)
    Deco:set_field("_SkillLvList", SkillLvParam)

    local DecoRef = Deco:add_ref()

    return Deco, DecoRef
end

function SkillAddModule.Internal.CreateBaseDeco(DecoRef)
    local Deco = sdk.create_instance("snow.data.DecorationBaseData", true)
    Deco:set_field("_Param", DecoRef)
    Deco:set_field("_ParamBase", DecoRef)
    Deco:call("initSkillData", DecoRef)

    DecoRef = Deco:add_ref()
    return Deco, DecoRef
end

function SkillAddModule.Internal.CreateUserDecoRecipe(PrivateId, DecoRef, DecoRecipe, ItemFlag, EnemyFlag, ProgressFlag, Price)
    local Recipe = sdk.create_instance("snow.data.DecorationsProductUserData.Param")

    Recipe:set_field("_Id", PrivateId)
    Recipe:set_field("_ItemFlag", ItemFlag)
    Recipe:set_field("_EnemyFlag", EnemyFlag)
    Recipe:set_field("_ProgressFlag", ProgressFlag)
    
    local ItemIdList = sdk.create_managed_array("snow.data.ContentsIdSystem.ItemId", 4)
    local ItemNumList = sdk.create_managed_array("System.UInt32", 4)
    for i = 1,4 do
        ItemIdList:call( "set_Item", i - 1, DecoRecipe[i][1])
        ItemNumList:call("set_Item", i - 1, DecoRecipe[i][2])
    end

    local ItemIdListParam =  ItemIdList:add_ref()
    local ItemNumListParam = ItemNumList:add_ref()

    Recipe:set_field("_ItemIdList",  ItemIdListParam)
    Recipe:set_field("_ItemNumList", ItemNumListParam)

    local RecipeRef = Recipe:add_ref()
    return Recipe, RecipeRef
end

function SkillAddModule.Internal.CreateBaseDecoRecipe(RecipeRef)
    local Recipe = sdk.create_instance("snow.data.EquipRecipeData", true)

    Recipe:call(".ctor(snow.data.DecorationsProductUserData.Param)", RecipeRef)
    Recipe:call("set_Price", RecipeRef:get_field("_Value"))

    local RecipeRef = Recipe:add_ref()
    return Recipe, RecipeRef
end

function SkillAddModule.Internal.CreateDecoData(BaseData, RecipeData)
    local Deco = sdk.create_instance("snow.data.DecorationsData")
    Deco:call("set_BaseData", BaseData)
    Deco:call("set_ProductRecipeData", RecipeData)
    Deco:call("set_Id", BaseData:get_field("_Param"):get_field("_Id"))
    Deco:call("set_MaxCountInBox", 99)
    Deco:add_ref()
    return Deco
end

function SkillAddModule.Internal.AddDecoToSmith(BaseData, RecipeData)
    local smithy = sdk.get_managed_singleton("snow.data.FacilityDataManager")
    if smithy then 
        smithy = smithy:get_field("_Smithy"):get_field("_Function"):call("get__DecorationsProductFunc")
        local Deco = SkillAddModule.Internal.CreateDecoData(BaseData, RecipeData)
        local Array = SkillAddModule.Internal.AddToArray(smithy:call("get_AllProductList"):call("ToArray"), "snow.data.DecorationsData", Deco)
        smithy:call("get_AllProductList"):call("Clear")
        smithy:call("get_AllProductList"):call("AddRange", Array)
    end
end

function SkillAddModule.Internal.AddDecoToBox(BaseData, RecipeData)
    local box = sdk.get_managed_singleton("snow.data.DataManager")
    if box then 
        box = box:get_field("_PlDecorationsBox")
        local Deco = SkillAddModule.Internal.CreateDecoData(BaseData, RecipeData)
        local Array = SkillAddModule.Internal.AddToArray(box:call("get_UiDecorationDataList"):call("ToArray"), "snow.data.DecorationsData", Deco)
        box:call("get_UiDecorationDataList"):call("Clear")
        box:call("get_UiDecorationDataList"):call("AddRange", Array)
    end
end

function SkillAddModule.Internal.InitializeDeco(UserData, BaseData, RecipeUserData, RecipeData)
    local ContentsIdDataManager = sdk.get_managed_singleton("snow.data.ContentsIdDataManager")
    local DecoDataManager = ContentsIdDataManager:get_field("_PlDecorationsIdDataModule")

    local BaseUserDataList = DecoDataManager:get_field("_BaseUserData")
    local BaseUserDataArray = SkillAddModule.Internal.AddToArray(BaseUserDataList:get_field("_Param"), "snow.data.DecorationsBaseUserData.Param", UserData)
    local BaseUserDataRef = BaseUserDataArray:add_ref()
    BaseUserDataList:set_field("_Param", BaseUserDataRef)

    local BaseDataList = DecoDataManager:call("get_BaseDataList")
    local BaseDataArray = SkillAddModule.Internal.AddToArray(BaseDataList, "snow.data.DecorationBaseData", BaseData, UserData:get_field("_Id"))
    local BaseDataRef = BaseDataArray:add_ref()
    DecoDataManager:call("set_BaseDataList", BaseDataRef)

    local RecipeUserDataList = DecoDataManager:get_field("_ProductUserData")
    local RecipeUserDataArray = SkillAddModule.Internal.AddToArray(RecipeUserDataList:get_field("_Param"), "snow.data.DecorationsProductUserData.Param", RecipeUserData)
    local RecipeUserDataRef = RecipeUserDataArray:add_ref()
    RecipeUserDataList:set_field("_Param", RecipeUserDataRef)

    local RecipeDataList = DecoDataManager:call("get_ProductRecipeDataList")
    local RecipeDataArray = SkillAddModule.Internal.AddToArray(RecipeDataList, "snow.data.EquipRecipeData", RecipeData, UserData:get_field("_Id"))
    local RecipeDataRef = RecipeDataArray:add_ref()
    DecoDataManager:call("set_ProductRecipeDataList", RecipeDataRef)
end

function SkillAddModule.Decoration.AddDeco(PrivateId, rare, SortId, Color, Lv, SkillIds, Price, DecoRecipe, ItemFlag, EnemyFlag, ProgressFlag)
    local UserDeco, UserDecoRef = SkillAddModule.Internal.CreateUserDeco(PrivateId, rare, SortId, Color, Lv, SkillIds, Price)
    local BaseDeco, BaseDecoRef = SkillAddModule.Internal.CreateBaseDeco(UserDecoRef)

    local UserReci, UserReciRef = SkillAddModule.Internal.CreateUserDecoRecipe(PrivateId, BaseDecoRef, DecoRecipe, ItemFlag, EnemyFlag, ProgressFlag, Price)
    local BaseReci, BaseReciRef = SkillAddModule.Internal.CreateBaseDecoRecipe(UserReciRef)

    SkillAddModule.Internal.InitializeDeco(UserDeco, BaseDeco, UserReci, BaseReci)

    SkillAddModule.Internal.AddDecoToSmith(BaseDecoRef, BaseReciRef)
    --SkillAddModule.Internal.AddDecoToBox(BaseDecoRef, BaseRecipeRef)

    return UserDeco, BaseDeco, UserReci, BaseReci
end


re.on_script_reset(function()
    local armorData = sdk.get_managed_singleton("snow.data.ContentsIdDataManager"):get_field("_PlArmorIdDataModule")
    dataList = armorData:call("get_ArmorSeriesDataList")

    for i,EditArmor in pairs(AffectedArmorIds) do
        ArmorIndex = EditArmor[1]
        local data = dataList:get_element(ArmorIndex)
        --local func = "get_".. (EditArmor[1] and "Ex" or "") .."ArmorIdList"
        local func = "get_ArmorIdList"

        for i,pieceId in pairs(EditArmor[2]) do
            local pieceBaseData = armorData:call("getBaseData", pieceId)
            local piecePlainData = armorData:call("getPlainArmorData", pieceId)
            local skillDataList = pieceBaseData:call("get_AllSkillDataList")
            for i = 0, skillDataList:call("get_Count") -1 do
                local skillData = skillDataList:call("get_Item", i)
                if skillData:call("get_EquipSkillId") > SkillAddModule.HighestKnownSkill then
                    skillData:call("set_EquipSkillId", SkillId)
                    for i = 0, 7 do
                        skillData:call("get_LvList"):call("set_Item", i, 0)
                    end
                end
            end
            piecePlainData:call("updateSkillDataList")
        end
        data:call("updateSeriesSkillList")
    end
end)

return SkillAddModule