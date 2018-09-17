/*
    Spectate script written by Thunder Rahja.
    This work is licensed under GNU GPLv3, which should be included with this script. 

    Instructions: Drop this script into an object, preferably an attachment. Spectate a target using the command
    "spec [name]" where [name] is a partial name of the target. Camera views can be changed with these commands:
    auto, shoulder, chase, nose. Camera offset can be changed with the command "offset [ratio]" which uses a default
    ratio of 1. To stop spectating, press any movement key (while not sitting) or use the command "stop" to return
    your camera to your avatar. When you first specify a target, you may have have to reset your camera (ESC) to begin
    spectating. This script listens on channel 13, which can be changed below.
*/

// Configuration
integer USER_CHANNEL = 13; // User channel

// Internal
integer cameraMode; // 0 = auto, 1 = shoulder, 2 = chase, 3 = nose
float camOffset = 1;
float refreshRate = 0.022222; // 45 FPS, the maximum possible under ideal conditions
key targetKey;
vector scaleOffset;
integer myPerms;

list FindNamesLike(string namePart) // returns strided list of names and UUIDs
{
    namePart = llDumpList2String(llParseString2List(llToLower(namePart), ["."], []), " ");
    list output;
    list agentList = llGetAgentList(AGENT_LIST_REGION, []);
    integer n = llListFindList(agentList, [llGetOwner()]);
    agentList = llDeleteSubList(agentList, n, n); // remove owner from list
    n = llGetListLength(agentList);
    while (n--)
    {
        key agentKey = llList2Key(agentList, n);
        string agentName = llKey2Name(agentKey);
        if (llSubStringIndex(llToLower(agentName), namePart) == 0)
        {
            if (llGetSubString(agentName, -9, -1) == " Resident")
                agentName = llDeleteSubString(agentName, -9, -1);
            if (llToLower(agentName) == namePart) // exact match found
            {
                return [agentName, agentKey];
            }
            else output += [agentName, agentKey];
        }
    }
    return llListSort(output, 2, TRUE);
}

Stop()
{
    llSetTimerEvent(0);
    targetKey = "";
    if (myPerms & PERMISSION_CONTROL_CAMERA) llClearCameraParams();
    llReleaseControls();
}

default
{
    state_entry()
    {
        if (llGetAttached()) llRequestPermissions(llGetOwner(), PERMISSION_CONTROL_CAMERA);
        llListen(USER_CHANNEL, "", llGetOwner(), "");
    }
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
        else if (change & CHANGED_TELEPORT)
        {
            Stop();
        }
    }
    attach(key id)
    {
        if (id) Stop();
    }
    run_time_permissions(integer perm)
    {
        myPerms = perm;
        if (perm & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls(831, TRUE, TRUE); // All movement controls
        }
        if (perm & PERMISSION_CONTROL_CAMERA)
        {
            if (targetKey)
            {
                llSetTimerEvent(refreshRate);
            }
            else
            {
                llClearCameraParams();
            }
        }
    }
    listen(integer channel, string name, key id, string text)
    {
        list params = llParseString2List(text, [" "], []);
        string command = llToLower(llList2String(params, 0));
        if (command == "spec")
        {
            string targetName = llDumpList2String(llDeleteSubList(params, 0, 0), " ");
            list matches = FindNamesLike(targetName);
            integer matchCount = llGetListLength(matches);
            if (matchCount > 2)
            {
                llOwnerSay("Clarify target: " + llDumpList2String(llList2ListStrided(matches, 0, -1, 2), " | "));
            }
            else if (matchCount == 0)
            {
                llOwnerSay("Target not found: " + targetName);
            }
            else
            {
                targetKey = llList2Key(matches, 1);
                vector targetSize = llGetAgentSize(targetKey);
                scaleOffset = <0, 0, targetSize.z * 0.48>;
                llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS | PERMISSION_CONTROL_CAMERA);
            }
        }
        else if (command == "stop")
        {
            Stop();
        }
        else if (command == "auto")
        {
            cameraMode = 0;
        }
        else if (command == "shoulder")
        {
            cameraMode = 1;
        }
        else if (command == "chase")
        {
            cameraMode = 2;
        }
        else if (command == "nose")
        {
            cameraMode = 3;
        }
        else if (command == "offset")
        {
            float newOffset = (float)llDeleteSubString(text, 0, 6);
            if (newOffset > 0)
            {
                camOffset = newOffset;
                llOwnerSay("Camera offset ratio: " + (string)newOffset);
            }
        }
        else if (command == "rate")
        {
            integer newRate = llList2Integer(params, 1);
            if (newRate > 45) newRate = 45;
            if (newRate > 0)
            {
                refreshRate = 1.0 / newRate;
                if (targetKey) llSetTimerEvent(refreshRate);
                llOwnerSay("Camera update rate: " + (string)newRate + " FPS.");
            }
        }
    }
    control(key id, integer level, integer edge)
    {
        Stop();
    }
    timer()
    {
        if (targetKey)
        {
            if (myPerms & PERMISSION_CONTROL_CAMERA)
            {
                list targetInfo = llGetObjectDetails(targetKey, [OBJECT_POS, OBJECT_ROT]);
                vector targetPos = llList2Vector(targetInfo, 0);
                if (targetPos)
                {
                    vector newCameraPos;
                    rotation targetRot = llList2Rot(targetInfo, 1);
                    integer effectiveMode = cameraMode;
                    if (cameraMode == 0) // auto
                    {
                        if (llGetAgentInfo(targetKey) & AGENT_MOUSELOOK) effectiveMode = 3;
                        else effectiveMode = 1;
                    }
                    if (effectiveMode == 1) // shoulder
                        newCameraPos = targetPos + scaleOffset +
                        <-camOffset * 1.5, -camOffset * 0.5, camOffset * 0.25> * targetRot;
                    else if (effectiveMode == 2) // chase
                        newCameraPos = targetPos +
                        <-camOffset * 3, 0, camOffset> * targetRot;
                    else if (effectiveMode == 3) // nose
                        newCameraPos = targetPos + scaleOffset +
                        <camOffset, 0, 0> * targetRot;
                    vector newCameraFocus = newCameraPos + <5,0,0> * targetRot;
                    llSetCameraParams([CAMERA_ACTIVE, TRUE, CAMERA_FOCUS, newCameraFocus, CAMERA_POSITION, newCameraPos,
                        CAMERA_POSITION_LOCKED, TRUE, CAMERA_FOCUS_LOCKED, TRUE]);
                }
                else
                {
                    if (llGetAgentSize(targetKey) == ZERO_VECTOR)
                    {
                        llOwnerSay("Target lost.");
                        Stop();
                    }
                }
            }
        }
    }
}
