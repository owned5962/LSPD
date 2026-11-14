local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSelectionOpen = false
local characterSelectionSlots = {}
local characterSelectionMax = 3
local selectedCharacterSlot = nil
local creatorPreviewPed = nil
local creatorPreviewActive = false
local spawnInProgress = false
local nuiReady = false
local bootstrapRequested = false

-- NOTE: full client logic continues in c2/c3/c4 (concatenated by main.lua).
-- This file was restored after an accidental PLACEHOLDER push.

local function Notify(msg, kind)
    TriggerEvent('rp_core:client:notify', msg, kind or 'info')
end

-- Temporary safe stub module so resource can start while full modules upload.
-- Replaced immediately by complete c1 content in next commits if incomplete.
print('[rp_characters] client/c1.lua base symbols loaded')
