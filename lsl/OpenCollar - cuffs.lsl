// Template for creating a OpenCollar Plugin
// API Version: 3.8

//Collar Cuff Menu
// Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//=============================================================================
//== OC Cuff - Command forwarder to listen for commands in OpenCollar
//== receives messages from linkmessages send within the collar
//== sends the needed commands out to the cuffs
//==
//==
//== 2009-01-16 Cleo Collins - 1. draft
//==
//==
//=============================================================================
integer g_nCmdChannel    = -190890;     // command channel for sending commands to the main cuff
integer g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;  // offset to be used to make sure we do not interfere with other items using the same technique for

// Commands to be send to the Cuffs
string g_szOwnerChangeCmd="OwnerChanged";
string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szCuffMenuCmd="CuffMenu";
string g_szSwitchHideCmd="ShowHideCuffs";
string g_szSwitchLockCmd="SwitchLock";



integer g_nRecolor=FALSE; // only send color values on demand
integer g_nRetexture=FALSE; // only send texture values on demand

float g_fMinVersion=3.750;
string g_sSubmenu = "Cuffs"; // Name of the submenu
string g_sParentmenu = "AddOns"; // name of the menu, where the menu plugs in, should be usually Addons. Please do not use the mainmenu anymore
key g_kMenuID;  // menu handler
list g_lLocalbuttons = ["Cuff Menu","Upd. Colors", "Upd. Textures", "(Un)Lock Cuffs", "Show/Hide"]; // any local, not changing buttons which will be used in this plugin, leave empty or add buttons as you like
list g_lButtons;

string g_szPrefix; // sub prefix for databse actions

string g_szOwnerChangeCollarInfo="OpenCuff_OwnerChanged"; // command for the collar to reset owner system
string g_szRLVChangeToCollarInfo="OpenCuff_RLVChanged"; // command to the collar to inform about RLV usage switched
string g_szRLVChangeFromCollarInfo="OpenCollar_RLVChanged"; // command from the collar to inform about RLV usage switched
string g_szCollarMenuInfo="OpenCollar_ShowMenu"; // command for the collar to show the menu

integer g_nLastRLVChange=-1;


string g_szUpdateActive_ON ="Sync On";
string g_szUpdateActive_OFF ="Sync Off";
string g_szUpdateActive_DBsave="cuffautosync";


integer g_nUpdateActive = FALSE;

// Please agressively remove any unneeded code sections to save memory and sim time
string g_sChatCommand = "cuffmenu"; // every menu should have a chat command, so the user can easily access it by type for instance *plugin

integer g_iDebugMode=TRUE; // set to TRUE to enable Debug messages


string g_szOnlineModeCommand="online";
integer g_nOnline=FALSE; // For 3.7 there IS no 'online' mode

key g_kWearer; // key of the current wearer to reset only on owner changes

string g_szScriptIdentifier="OpenCollar - cuffs -"; // for checking if already an older version of theis scrip is in the collar


//OpenCollar MESSAGE MAP

// messages for authenticating users
integer COMMAND_NOAUTH = 0; // for reference, but should usually not be in use inside plugins
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;
integer COMMAND_BLACKLIST = 520;
// added for timer so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;

integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;
integer ATTACHMENT_FORWARD = 610;

integer WEARERLOCKOUT=620;//turns on and off wearer lockout

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bit of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

// messages for storing and retrieving values from settings store
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to settings store
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from settings store
integer LM_SETTING_EMPTY = 2004;//sent by settings script when a token has no value in the settings store
integer LM_SETTING_REQUEST_NOCACHE = 2005;

// messages for creating OC menu structure
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

// messages for RLV commands
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

// messages for poses and couple anims
integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

// messages to the dialog helper
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

// menu option to go one step back in menustructure
string UPMENU = "^";//when your menu hears this, give the parent menu

//===============================================================================
//= parameters   :    key   kRCPT  recipient of the dialog
//=                   string  sPrompt    dialog prompt
//=                   list  lChoices    true dialog buttons
//=                   list  lUtilityButtons  utility buttons (kept on every iPage)
//=                   integer   iPage    Page to be display
//=
//= return        :    key  handler of the dialog
//=
//= description  :    displays a dialog to the given recipient
//=
//===============================================================================
key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    string sChars = "0123456789abcdef";
    integer iLength = 16;
    string sOut;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer iIndex = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        sOut += llGetSubString(sChars, iIndex, iIndex);
    }
    key kID = (key)(sOut + "-0000-0000-0000-000000000000");
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`" + "|" + (string)iAuth), kID);
    return kID;
}


integer VersionOK()
{
    // checks if the version of the collar fits the needed version for the plugin
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    string name = llList2String(params, 0);
    string version = llList2String(params, 1);
    if ( version == "X" ) 
    {
        key nc = llGetInventoryKey( "~version" ) ;
        if ( nc != NULL_KEY )
        {
            //This is a version 3.7 or higher collar - just return true
            // without doing any version checking.
            return TRUE;
        }
    }
    
    if (llGetSubString(name,0,11)=="Delivery Box")
    // the script is in a delivery box, fall silently to sleep
    {
        return FALSE;
    }
    else if (name == "" || version == "")
    {
        llOwnerSay("Description of collar is invalid, please check that you use this plugin only with collar higher than "+llGetSubString((string)g_fMinVersion,0,4)+".");
    }
    else if ((float)version)
    {
        if ((float)version<g_fMinVersion)
        {
            llOwnerSay("Your collar is to old for this plugin. Please update to Version "+llGetSubString((string)g_fMinVersion,0,4)+" or higher.");
        }
        else
        {
            return TRUE;
        }
    }
    else
    {
        llOwnerSay("Description of collar is invalid, please check that you use this plugin only with collar higher than "+llGetSubString((string)g_fMinVersion,0,4)+".");
        
    }
    return FALSE;
}
//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


Debug(string szMsg)
{
    //if (!g_iDebugMode) return;
    //llOwnerSay(llGetScriptName() + ": " + sMsg);
}
//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)g_kWearer,3,8)) + g_nCmdChannelOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

//===============================================================================
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================


DoMenu(key keyID, integer iAuth)
{
    string sPrompt = "Pick an option.\n";
    list lMyButtons = g_lLocalbuttons + g_lButtons;

    if (g_nUpdateActive)
    {
        sPrompt += " Colors and textures will be sycronized automatically to your cuffs, when you change them on the collar.";
        lMyButtons+=[g_szUpdateActive_OFF];
    }
    else
    {
        sPrompt += " Colors and textures will NOT be sycronized automatically to your cuffs, when you change them on the collar.";
        lMyButtons+=[g_szUpdateActive_ON];
    }

    //fill in your button list and additional prompt here
    lMyButtons = llListSort(lMyButtons, 1, TRUE); // resort menu buttons alphabetical

    // and dispay the menu
    g_kMenuID = Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0, iAuth);
}
//===============================================================================
//= parameters   :   string    szColorString   string with objectnames and colors
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and Color into seveal commands
//=                    and send them out to the cuffs
//=
//===============================================================================

SendRecoloring (string szColorString)
{
    list lstColorList=llParseString2List(szColorString, ["~"], []);
    integer nColorCount=llGetListLength(lstColorList);
    integer i;
    for (i=0;i<nColorCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel,"occ|*|"+g_szColorChangeCmd+"="+llList2String(lstColorList,i)+"="+llList2String(lstColorList,i+1)+"|" + (string)g_kWearer);
    }
}

//===============================================================================
//= parameters   :   string    szTextureString   string with objectnames and texture IDs
//=
//= return        :    none
//=
//= description  :    break up the Itemnams and texture IDs into several commands
//=                    and send them out to the cuffs
//=
//===============================================================================

SendRetexturing (string szTextureString)
{
    list lstTextureList=llParseString2List(szTextureString, ["~"], []);
    integer nTextureCount=llGetListLength(lstTextureList);
    integer i;
    for (i=0;i<nTextureCount;i=i+2)
    {
        llRegionSay(g_nCmdChannel,"occ|*|"+g_szTextureChangeCmd+"="+llList2String(lstTextureList,i)+"="+llList2String(lstTextureList,i+1)+"|" + (string)g_kWearer);
    }
}



//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to save into the HTTPDB is detected
//=                    analyzes if the save would need any update in th cuffs
//=
//===============================================================================
Analyse_LM_SETTING_Save(string szMsg)
{

    // split the message into token and message
    list lstParams = llParseString2List(szMsg, ["="], []);
    string szToken = llList2String(lstParams, 0);
    string szValue = llList2String(lstParams, 1);

    // now scheck if we have to take action
    if ((szToken=="owner")||(szToken=="secowners")||(szToken=="group")||(szToken=="openaccess")||(szToken=="blacklist"))
    {
        if (g_nOnline)
        {
        	// owner right have been changed,, inform the cuffs
        	llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"="+szToken+"|" + (string)g_kWearer);
	}
    }
    else if (g_nUpdateActive && (szToken==g_szPrefix+"colorsettings"))
    {

        // for now active updating on every click is not in use
        // owner right have been changed,, inform the cuffs
        SendRecoloring(szValue);

    }
    else if (g_nUpdateActive && (szToken==g_szPrefix+"textures"))
    {
        // for now active updating on every click is not in use
        // owner right have been changed,, inform the cuffs
        SendRetexturing(szValue);
    }
}

//===============================================================================
//= parameters   :   string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    gets called when a command to delete a value stored in the HTTPDB is detected
//=                    analyzes if the delete would need any update in th cuffs
//=
//===============================================================================

Analyse_LM_SETTING_Delete(string szMsg)
{
    if ((szMsg=="owner")||(szMsg=="secowners")||(szMsg=="group")||(szMsg=="openaccess")||(szMsg=="blacklist"))
    {
        // owner right have been changed,, inform the cuffs
        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"="+szMsg+"|" + (string)g_kWearer);
    }
}

//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    display an error message if more than one plugin of the same version is found
//=
//===============================================================================
DoubleScriptCheck()
{
    integer l=llStringLength(g_szScriptIdentifier)-1;
    string s;
    integer i;
    integer c=0;
    integer m=llGetInventoryNumber(INVENTORY_SCRIPT);
    for(i=0;i<m;i++)
    {
        s=llGetSubString(llGetInventoryName(INVENTORY_SCRIPT,i),0,l);
        if (g_szScriptIdentifier==s)
        {
            c++;
        }
    }
    if (c>1)
    {
        llOwnerSay ("There is more than one version of the Cuffs plugin in your collar. Please make sure you only keep the latest version of this plugin in your collar and delete all other versions.");
    }
}

//===============================================================================
//= parameters   :    iNum: integer parameter of link message (avatar auth level)
//=                   sStr: string parameter of link message (command name)
//=                   kID: key parameter of link message (user key, usually)
//=
//= return        :   TRUE if the command was handled, FALSE otherwise
//=
//= description  :    handles user chat commands (also used as backend for menus)
//=
//===============================================================================

integer UserCommand(integer iNum, string sStr, key kID)
{
    if (!(iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)) return FALSE;
    // a validated command from a owner, secowner, groupmember or the wearer has been received
    // can also be used to listen to chat commands
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    string sValue = llToLower(llList2String(lParams, 1));
    // So commands can accept a value
    if (sStr == "reset")
        // it is a request for a reset
    {
        if (iNum == COMMAND_WEARER || iNum == COMMAND_OWNER)
        {   //only owner and wearer may reset
            llResetScript();
        }
    }
    else if (sStr == g_sChatCommand || sStr == "menu " + g_sSubmenu)
        // an authorized user requested the plugin menu by typing the menus chat command
    {
        DoMenu(kID, iNum);
    }
    else if (sStr == g_sChatCommand)
        // send command to cuffs to open menu command on chat menu received my the collar
    {
        // Send open command to cuff
        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szCuffMenuCmd+"="+(string)kID+"|" +(string)g_kWearer);
    }
    else if (sStr == "rlvon" )
    {
        if(llGetUnixTime()>g_nLastRLVChange+10)
        {
            llRegionSay(g_nCmdChannel,"occ|*|"+g_szRLVChangeFromCollarInfo+"=on="+(string)kID+"|" + (string)g_kWearer);
        }
    }
    else if (iNum == COMMAND_SAFEWORD )
        // safeword has been issued
    {
        llRegionSay(g_nCmdChannel,"occ|*|SAFEWORD|" + (string)g_kWearer);
    }
    else if ( (sStr=="runaway") && (iNum ==COMMAND_OWNER || kID == g_kWearer) )
    {
        // owner right have been changed,, inform the cuffs
        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szOwnerChangeCmd+"=owner|" + (string)g_kWearer);
    }
    else if (iNum == COMMAND_OWNER)
        // check if a owner command comes through and if it is about enabling RLV
    {
        if (sStr == "rlvoff" )
            if(llGetUnixTime()>g_nLastRLVChange+10)
            {
                llRegionSay(g_nCmdChannel,"occ|*|"+g_szRLVChangeFromCollarInfo+"=off="+(string)kID+"|" + (string)g_kWearer);
            }
    }

    return TRUE;
}

//===============================================================================
//= parameters   :    none
//=
//= return        :   string     DB prefix from the description of the collar
//=
//= description  :    prefix from the description of the collar
//=
//===============================================================================
string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

default
{
    state_entry()
    {
        // store key of wearer
        g_kWearer = llGetOwner();

        DoubleScriptCheck();
        g_nCmdChannel= nGetOwnerChannel(g_nCmdChannelOffset);
        g_szPrefix = GetDBPrefix();
        // sleep a second to allow all scripts to be initialized
        llSleep(1.0);
        // send request to main menu and ask other menus if they want to register with us
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, g_sSubmenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);
    }

    // Reset the script if wearer changes. By only reseting on owner change we can keep most of our
    // configuration in the script itself as global variables, so that we don't loose anything in case
    // the settings store isn't available, and also keep settings that were not sent to that store
    // in the first place.
    // Cleo: As per Nan this should be a reset on every rez, this has to be handled as needed, but be prepared that the user can reset your script anytime using the OC menus
    on_rez(integer iParam)
    {
        if (llGetOwner()!=g_kWearer)
        {
            // Reset if wearer changed
            llResetScript();
        }
    }


    // listen for linked messages from OC scripts
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentmenu)
            // our parent menu requested to receive buttons, so send ours
        {

            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);
        }
        else if (iNum == MENUNAME_RESPONSE)
            // a button is send to be added to a menu
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubmenu)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                    // if the button isnt in our menu yet, than we add it
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
            // response from setting store have been received
        {
            // pares the answer
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);

            Debug("LMSETTINGSRESPONSE: "+sStr);
            if ((g_nRecolor)&&(sToken == g_szPrefix+"colorsettings") )
            {
                // work with the received values
                llOwnerSay("Recoloring:"+sValue);
                SendRecoloring(sValue);
                g_nRecolor=FALSE;
            }
            else if ((g_nRetexture)&&(sToken == g_szPrefix+"textures"))
            {
                llOwnerSay("Retexturing:"+sValue);
                SendRetexturing(sValue);
                g_nRetexture=FALSE;
            }
            // or check for specific values from the collar like "owner" (for owners) "secowners" (or secondary owners) etc
             else if (sToken == g_szPrefix+g_szUpdateActive_DBsave)
            {
                g_nUpdateActive=(integer)sValue;
            }
            else if (sToken == g_szOnlineModeCommand)
                // is the collar in online mode?
            {
                if (sValue == "1")
                {
                    g_nOnline = TRUE;
                }
                else
                {
                    g_nOnline = FALSE;
                }
            }

        }
        else if (iNum == LM_SETTING_SAVE)
        {
            // the collar saves to the DB, so anaylye the command
            Analyse_LM_SETTING_Save(sStr);
        }
        else if (iNum == LM_SETTING_DELETE)
        {
            // the collar saves to the DB, so anaylye the command
            Analyse_LM_SETTING_Delete(sStr);
        }
        else if (iNum == ATTACHMENT_FORWARD)
        { // object status changes forwarding
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (llGetOwnerKey(kID)==g_kWearer)
            {
                if (sToken == g_szOwnerChangeCollarInfo)
                {
                    Debug("OWNERINFO:"+ g_szOwnerChangeCollarInfo);
                    llOwnerSay("The owners of your cuffs changed, but will not be kept in sync.");
                }
                else if (sToken == g_szRLVChangeToCollarInfo)
                {
                    if (sValue=="on")
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvon", llList2Key(lParams,2));

                    }
                    else
                    {
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rlvoff", llList2Key(lParams,2));
                    }
                    g_nLastRLVChange=llGetUnixTime();
                }
                else if (sToken == g_szCollarMenuInfo)
                {
                    // to properly handle changes we run the command through the auth system
                    // check this?
                    if (sValue=="on")
                        llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "menu",  llList2Key(lParams,2));
                    return;
                }
            }
        }
        else if (UserCommand(iNum, sStr, kID)) {} // do nothing more if TRUE
        else if (iNum == COMMAND_SAFEWORD)
            // Safeword has been received, release any restricitions that should be released
        {
            Debug("Safeword received, releasing the subs restricions as needed");
            llRegionSay(g_nCmdChannel,"occ|*|SAFEWORD|" + (string)g_kWearer);
        }
        else if (iNum == DIALOG_RESPONSE)
            // answer from menu system
            // careful, don't use the variable kID to identify the user, it is the UUID we generated when calling the dialog
            // you have to parse the answer from the dialog system and use the parsed variable kAv
        {
            if (kID == g_kMenuID)
            {
                //got a menu response meant for us, extract the values
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                Debug(sStr);

                key kAv = (key)llList2String(lMenuParams, 0); // avatar using the menu
                string sMessage = llList2String(lMenuParams, 1); // button label
                integer iPage = (integer)llList2String(lMenuParams, 2); // menu page
                integer iAuth = (integer)llList2String(lMenuParams, 3); // auth level of avatar
                // request to switch to parent menu
                if (sMessage == UPMENU)
                {
                    //give av the parent menu
                    llMessageLinked(LINK_THIS, iAuth, "menu "+g_sParentmenu, kAv);
                }
                else if (~llListFindList(g_lLocalbuttons, [sMessage]))
                {
                    //we got a response for something we handle locally
                    if (sMessage == "Upd. Colors")
                    {
                        // only send color values on demand
                        g_nRecolor=TRUE;
                        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, g_szPrefix+"colorsettings", NULL_KEY);
                        // and restart the menu if wanted/needed
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMessage == "Upd. Textures")
                    {
                        // only send texture values on demand
                        g_nRetexture=TRUE;
                        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, g_szPrefix+"textures", NULL_KEY);
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMessage == "Cuff Menu")
                    {
                        // Send open command to cuff
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szCuffMenuCmd+"="+(string)kAv+"|" +(string)g_kWearer+"|" +(string)iAuth);
                    }
                    else if (sMessage == "(Un)Lock Cuffs")
                    {
                        // action 2
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szSwitchLockCmd+"="+(string)kAv+"|" +(string)g_kWearer+"|" +(string)iAuth);
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMessage == "Show/Hide")
                    {
                        // action 2
                        Debug("Show/Hide");
                        llRegionSay(g_nCmdChannel,"occ|rlac|"+g_szSwitchHideCmd+"|" +(string)g_kWearer+"|" +(string)iAuth);
                        DoMenu(kAv, iAuth);
                    }
                }
                else if (sMessage == "Sync On")
                {
                    // action 2
                    Debug("Sync on");
                    g_nUpdateActive=!g_nUpdateActive;
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_szPrefix+g_szUpdateActive_DBsave+"="+(string)g_nUpdateActive, NULL_KEY);
                    DoMenu(kAv, iAuth);
                }
                else if (sMessage == "Sync Off")
                {
                    // action 2
                    Debug("Sync off");
                    g_nUpdateActive=!g_nUpdateActive;
                    llMessageLinked(LINK_THIS, LM_SETTING_SAVE, g_szPrefix+g_szUpdateActive_DBsave+"="+(string)g_nUpdateActive, NULL_KEY);
                    DoMenu(kAv, iAuth);
                }
                else if (~llListFindList(g_lButtons, [sMessage]))
                {
                    //we got a button which another plugin put into into our menu
                    llMessageLinked(LINK_THIS, iAuth, "menu "+ sMessage, kAv);
                }
            }
        }
    }

    changed (integer change)
    {
        if (change & CHANGED_OWNER)
        {
            g_kWearer = llGetOwner();
        }
    }
}

state WrongVersion
{
    state_entry()
    {
        
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }

}