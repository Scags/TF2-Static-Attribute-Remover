#include <dhooks>
#include <smmem>
#include <smmem_vec>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

#define DEBUG 0

#if DEBUG
#include <profiler>
#endif

public Plugin myinfo =  {
	name = "[TF2] Static Attribute Remover", 
	author = "Scag", 
	description = "Remove static attributes for items", 
	version = PLUGIN_VERSION, 
	url = ""
};

Address
	g_StaticAttrOffset,
	g_ItemNameOffset
;

StringMap
	g_Attribs
;

// So strictly immolating an attribute from a econ def's vector probably leaks memory 
// so lets add them back when the function is done iterating
//ArrayStack
//	g_AttribHandler
//;

enum struct static_attrib_t
{
	int defindex;
	any value;
//	bool gctrash;
//	ptr kv;
}

public void OnPluginStart()
{
	GameData conf = new GameData("tf2.staticattrs");
	DynamicDetour d = DynamicDetour.FromConf(conf, "CEconItemDefinition::IterateAttributes");
	d.Enable(Hook_Pre, CEconItemDefinition_IterateAttributes);
//	d.Enable(Hook_Post, CEconItemDefinition_IterateAttributes_Post);

	g_StaticAttrOffset = ptr(conf.GetOffset("CEconItemDefinition::m_vecStaticAttributes"));
	g_ItemNameOffset = ptr(conf.GetOffset("CEconItemDefinition::m_pszItemBaseName"));
	delete conf;

	g_Attribs = new StringMap();
//	g_AttribHandler = new ArrayStack(sizeof(static_attrib_t));

	RegAdminCmd("sm_resetattrcfg", ResetAttrCfg, ADMFLAG_ROOT, "Reset tf2staticattr CFG");

	RunCfg();
}

public Action ResetAttrCfg(int client, int args)
{
	RunCfg();
	ReplyToCommand(client, "[SM] Running config.");
}

public void RunCfg()
{
	ResetCfg();
	char cfg[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cfg, sizeof(cfg), "configs/tf2staticattr.cfg");

	KeyValues kv = new KeyValues("Static Attributes");
	if (!kv.ImportFromFile(cfg))
	{
		LogError("Could not find config in \"configs/tf2staticattr.cfg\"");
		delete kv;
		return;
	}

	if (kv.GotoFirstSubKey(false))
	{
		char name[128], defidxname[32];
		do
		{
			ArrayList list = new ArrayList();
			kv.GetSectionName(name, sizeof(name));
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					kv.GetSectionName(defidxname, sizeof(defidxname));
					if (kv.GetNum(NULL_STRING))
						list.Push(StringToInt(defidxname));
				}	while kv.GotoNextKey(false);
				if (list.Length)
					g_Attribs.SetValue(name, list);
				else delete list;
				kv.GoBack();
			}
		}	while kv.GotoNextKey(false);
	}
}

public void ResetCfg()
{
	StringMapSnapshot snap = g_Attribs.Snapshot();

	char buffer[128];
	for (int i = 0; i < snap.Length; ++i)
	{
		snap.GetKey(i, buffer, sizeof(buffer));
		ArrayList list;
		g_Attribs.GetValue(buffer, list);
		delete list;
	}

	delete snap;
	g_Attribs.Clear();
}

#if 0
struct static_attrib_t
{
	int16 iDefIndex;					// +0
	union {int, float, byte*} m_value;	// +4
//	bool bForceGCToGenerate;			// +8
//	KeyValues *m_pKVCustomData;			// +12
}
#endif

#define SIZEOF_ATTR 8

#if DEBUG
Profiler g_Prof;
float proftimes[(1 << 16)];
int profcount;
#endif

// This fires a LOT (~1000/sec on a full server)
public MRESReturn CEconItemDefinition_IterateAttributes(Address pThis)
{
#if DEBUG
	g_Prof = new Profiler();
	g_Prof.Start();
#endif

//	static ArrayList lol;
//	if (!lol) lol = new ArrayList();
//	if (lol.FindValue(pThis) == -1)
//		lol.Push(pThis);
//	PrintToServer("0x%X, %d", pThis, lol.Length);

	char name[128];
	// Alright now let's fuck this string up
	ptr m_pszItemBaseName = Deref(pThis + g_ItemNameOffset);
	int count;
	bool breakout;
	do
	{
		// Do it 4 bytes at a time (SourceHook::SetMemAccess is slowwww)
		int p = Deref(m_pszItemBaseName + ptr(count));
		int byte = 0xFF;
		int shiftcount;
		do
		{
			int c = p & byte;
			if (c == '\0')
			{
				breakout = true;
				break;
			}
			c >>= shiftcount++ * 8;

			name[count++] = c;
			byte <<= 8;
		}	while byte;
	}	while !breakout;

//	PrintToServer("firing %s", name);
	if (name[0] == '\0')
		return;

	ArrayList list;
	if (!g_Attribs.GetValue(name, list))
		return;

	CUtlVector vec = CUtlVector(pThis + g_StaticAttrOffset);
	static_attrib_t attrib;
	for (int i = vec.m_Size-1; i >= 0; --i)
	{
		ptr p = vec.Element(i, SIZEOF_ATTR);
		attrib.defindex = Deref(p);
		int idx = list.FindValue(attrib.defindex);
		if (idx == -1)
			continue;

//		PrintToChatAll("firing %s %d", name, idx);

		// Yes, this can cause a memory leak. Too bad!
		vec.FastRemove(i, SIZEOF_ATTR);
//		attrib.value = Deref(p + ptr(4));

		// Which is why we push it to a stack and add it back later
//		g_AttribHandler.PushArray(attrib);
	}
}

#if 0
public MRESReturn CEconItemDefinition_IterateAttributes_Post(Address pThis)
{
	static_attrib_t attrib;
	CUtlVector vec = CUtlVector(pThis + g_StaticAttrOffset);
	while (!g_AttribHandler.Empty)
	{
		g_AttribHandler.PopArray(attrib);
		int i = vec.AddToTail(_, SIZEOF_ATTR);
		vec.Set(i, attrib.defindex, SIZEOF_ATTR);
		vec.Set(i, attrib.value, SIZEOF_ATTR, 4);
	}

#if DEBUG
	g_Prof.Stop();
	proftimes[profcount++ % (1 << 16)] = g_Prof.Time;
	delete g_Prof;

	PrintToServer("%d %f", profcount, 1000.0 * GetAverageTime(proftimes, sizeof(proftimes), profcount));
#endif
}
#endif

stock float GetAverageTime(float[] array, int size, int len)
{
	float fmax;
	int max = len >= size ? size : len;
	for (int i = 0; i < max; ++i)
		fmax += array[i];

	return fmax / max;
}