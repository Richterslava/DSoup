/**

@autor Robert Winther Bue (robert.bue@gmail.com)
@copyright - do whatever you want with it :) 

test
*/


import std.stdio;
import std.file;
import std.array;
import std.string;
import std.algorithm;
import std.json;
import std.datetime;
import std.regex;

class ReadEnd : Exception {
	this(string s) {
		super(s);	
	}
}

struct Attrib
{
    string name;
    string value;
}

struct Tag
{
    string name;
    Attrib[] attrib;
    string raw;
    string content;
    Tag[] children;

    public string text_content() {
        return remove_tags(content);
    }
    
    public string markup_content() {
        return content;
    }
}

struct SoupFilter
{
    alias bool function(string, string) DgType;
    private DgType[] delFuncs; // array with functions :D
    private string[string] attribs;
    private Regex!char[string] regAttribsV;
    private string[Regex!char] regAttribsK;
    private Regex!char[Regex!char] regAttribsKV;
    private bool _recursive;
    private bool _sensitive;
    
    static SoupFilter opCall() {
         SoupFilter t = SoupFilter(1);
         return t;
    }
    
    public this(int n)
    {
        this._recursive = true;
        this._sensitive = false;
    }
    
    public SoupFilter sensitive(bool x = true) {
        _sensitive = x;
        return this;
    }
    
    public SoupFilter recursive(bool x = true) {
        _recursive = x;
        return this;
    }
    
    public bool getSense() {
        return _sensitive;
    }
    
    public bool getRec() {
        return _recursive;
    }
    
    public SoupFilter add(string name, string value = null) {
        attribs[name] = value;
        return this;
    }
    
    public SoupFilter add(string name, Regex!char value) {
        regAttribsV[name] = value;
        return this;
    }
            
    public SoupFilter add(Regex!char name, Regex!char value) {
        regAttribsKV[name] = value;
        return this;
    }    
    
    public SoupFilter add(Regex!char name, string value) {
        regAttribsK[name] = value;
        return this;
    }
    
    public SoupFilter add(DgType filter_func) {
        delFuncs ~= filter_func;
        return this;
    }
}

struct DSoup
{
    string markup;
    Tag[] root;
    
    
    public this(string markup) {
        this.markup = markup; // ubrukelig jo....
        this.root = parse(this.markup);
    }
    
    public this(Tag[] m) {
        this.root = m;
    }
    
    public Tag[] get_root() {
        return root;
    }

    public string pretty_print(Tag[] tags = null, int current_indent = 0)
    {
        string s;
        if (tags == null)
            tags = root;
        foreach(t;tags)
        {
            foreach(i;0..current_indent)
                s ~= " ";
            
            s ~= cs(t.name);
            foreach(a;t.attrib)
                s ~= " " ~ a.name ~ "=" ~ "\"" ~ a.value ~ "\"";
            s ~= " | " ~ t.text_content();
            
            
            
            /*    
            s ~= "\n";
            foreach(i;0..current_indent)
                s ~= " ";
                
            s ~= t.raw;
            */
            
            
            
            
            
            s ~= "\n";
            if (t.children.length > 0)
                s ~= pretty_print(t.children, current_indent + 4);
        }
        
        return s;
    }

    // from = tags so search from, null will give root
    private Tag[] _find_all(string tag_name, SoupFilter filter = SoupFilter(), Tag[] from = null)
    {
        Tag[] tags;
        if (from == null)
            from = this.root;
  
		
        foreach (t;from)
        {
            bool is_added = false;
            if (filter.attribs.length != 0) {
                foreach (k,v;filter.attribs) {
                    if (is_added)
                        break;
                    foreach (a;t.attrib) {
                        if ((k == a.name && v == a.value) || (k == a.name && v == null)) {
                            tags ~= t;
                            is_added = true;
                            break;
                        }
                    }
                }
            }
            
            if (filter.regAttribsV.length != 0 && !is_added) {
                foreach (k;filter.regAttribsV.byKey()) {
                    if (is_added)
                        break;
                    foreach (a;t.attrib) {
                        if (!is_added && k == a.name && match(a.value, filter.regAttribsV[k])) {
                            tags ~= t;
                            is_added = true;
                            break;
                        }
                    }
                }
            }
        
            if (!is_added && ((!filter.getSense() && (toLower(t.name) == toLower(tag_name))) || (filter.getSense() && (t.name == tag_name)))) {
                tags ~= t;
            }
            
            if (filter.getRec())
                if (t.children.length > 0)
                    tags ~= _find_all(tag_name, filter, t.children);
        }
        
        return tags;

    }
    

    public DSoup find_all(string tag_name, SoupFilter filter = SoupFilter())
    {
        return DSoup(_find_all(tag_name, filter));
    }

    
    public DSoup find(string tag_name, SoupFilter filter = SoupFilter())
    {
        Tag[] y;
        auto x = _find_all(tag_name, filter);
        if (x.length > 0)
            y ~= x[0];
            return DSoup(y);
        return DSoup("");
    }

    public Tag[] result() {
        return root;
    }

    public Tag[] parse(string s)
    {   
        int i = 0;
        auto p = new DSoupParser(s);

        Tag[] root;
        
        try
        {
            while (1)
            {   
                auto tag = Tag();

                // finn en tag
                p.move2tag_start();
                int L = i;
                // leser attribs i taggen
                string wholetag = p.readtag(); // hvordan skal readtag vite at dette er en komment da?
                tag.raw = wholetag;
                
                //parse attribs
                tag.attrib = p.parse_attribs(wholetag);
                //writeln(tag.attrib);
                
                string tag_name = tag_name(wholetag);
                tag.name = tag_name;

                if (startsWith(strip(wholetag), "!")) {

                }
                else if (endsWith(strip(wholetag), "/")) {
                    tag.content = "";
                } 
                else {
                    // hente alt innholdet inni tagen
                    string content = p.read_content(tag_name);
                    tag.content = content;
                }

                root ~= tag;
                
            }
        }
        catch (ReadEnd e)
        {
        }
        
        string[] ignore = ["!--", "script", "noscript", "!--<![endif]--", "![CDATA["];

        for (int L = 0; L < root.length; L++) 
        {   
			// hivs tag name innholder dette, skal det ikke parses!
            if (count(ignore, root[L].name) == 0)
                root[L].children = parse(root[L].content);
        }
        
        
        return root;

    } // parse end

}

class DSoupParser
{
    string s;
    int i;
    int len;
    
    this (string s) {
        this.s = s;
        i = 0;
        len = s.length;
    }
    
    char get() {
        if (i == len)
            throw new ReadEnd("faggot, KIDDING!!!");
        return s[i++];
    }
    
    void move2tag_start()
    {
        while (1) {
            auto d = get();

            if (d == '<')
                break;
        }
    }
    
    string readtag() 
    {
        //string wholetag;
        auto wholetag = std.array.appender!string("");
    
        bool comment = false;
        auto d = get();
        //wholetag ~= d;
        wholetag.put(d);
        
        if (d == '!') {
            d = get();
            //wholetag ~= d;
            wholetag.put(d);
            if (d == '-') {
                d = get();
                //wholetag ~= d;
                wholetag.put(d);
                    if (d == '-') {
                        comment = true;
                    }
            }
        }

        while (1)
        {
            d = get();
            if ((d == '>' && !comment) || (comment && (s[i-3..i] == "-->"))) 
                break;
            //wholetag ~= d;
            wholetag.put(d);
        }

        
        return wholetag.data;
    }
    
    string read_content(string this_tag) 
    {
        string tmp;
        int inside = 0;

        int content_start = i;
        int content_end = 0;
        while (1)
        {
            // hvis vi ikke har funnet slutt tag, og havnet på bunnen, så mangler jo jævla taggen... GOD DAMNIT!!!
            string tag;
            try {
                move2tag_start();
                tag = readtag();
            }
            catch (ReadEnd e) {
                break;	
            }
                
            // starts with ! ? then we know theres no content! or it it ends with /
            if (startsWith(strip(tag), "!") || endsWith(strip(tag), "/"))
                continue;
            
            string lal = tag_name(tag);
            if (lal == this_tag)
                inside++;
            
            // har vi funnet avslutnings taggen for taggen vi har funnet?
            if (tag == ("/"~this_tag)) {
                if (inside == 0) {
                    content_end = i - tag.length - 2;
                    break;
                }
                inside--;
            }
            
        }

        // fant ikke slutt tagenn.. GOD DAMNIT!!, men siste taggen... blir ikke med :/ why?
        if (content_end == 0) {
            content_end = len; // denne må være fra HELT root! absolutt første root elementet :( eller.. fuck it?
            i = content_start;
        }
        
        
        return s[content_start..content_end];
    }
    
    void find_comment_end()
    {
        while (i > 2)
        {
            auto d = get();
            if (d == '>')
            {
                //writeln(s[i-2..i]);
                if (s[i-2..i] == "-->")
                    break;
            }
        }
    }
    


    Attrib[] parse_attribs(string s_) 
    {
        Attrib[] attrs;
        bool space = false;
    
        s_ = cs(s_);
        auto ap = new DSoupParserAttrib(s_);
    
        
        // br / eks..
        /*
        if (s_[s_.length-1] == '/')
            return attrs;
        */
        
        try
        {
            
            while (1)
            {
                if (i == 0) {
                    auto c = ap.get();
                    // comment or doctype...
                    if (c == '!' && i == 1)
                        break;
                }
                
                
                // hvorfor? fordi, første navnet, er tag navnet... daaaa
                if (!space) {
                    auto c = ap.get();
                    if (c == ' ') 
                        space = true;
                    continue;
                }

                
                // readname
                string n = cs(ap.name());
                
                // avsluttende tag : br el.
                if (n == "/")
                    break;
                
                auto fnutt = ap.move2fnutt();
                // read value
                string v = cs(ap.value(fnutt));
                
                Attrib x;
                x.name = n;
                x.value = v;
                                            
                attrs ~= x;
            }
            
            
        }
        catch (Exception e) {}
/*
        writeln(s_);
        writeln(attrs);
        writeln();
  */      
        return attrs;
    }
}

class DSoupParserAttrib
{
    string s;
    int i;
    int len;
    this (string s) {
        this.s = s;
        i = 0;
        len = s.length;
    }
    
    char get() {
        if (i == len)
            throw new ReadEnd("faggot, KIDDING!!!");
        auto wtf = s[i++];
        return wtf;
    }

    // attrib_name
    string name() {
        //string n;
        auto n = std.array.appender!string("");
        while (1) 
        {
            auto c = get();

            
            
            if (c == '=')
                break;
        
            n.put(c);
        }
        
        return n.data;
    }
    
    char move2fnutt() {
        while (1)
        {
            auto d = get();
            if (d == '"') {
                return '"';
            }
            else if (d == '\'') {
                return '\'';
            }
        }
        return '"';
    }
    
    string value(char fnutt) {
        // string v;
        auto v = std.array.appender!string("");
        while (1)
        {
            auto d = get();
            if (d == fnutt)
                return v.data;
                
            //v ~= d;
            v.put(d);
        }
        return "";
    }
}


// fjerne HELE jævla <script> bla bla etc. </script> <style></style>
string remove_tags(string s)
{
    auto p = new DSoupParser(s);

    //string content;
    auto content = std.array.appender!string("");
    try
    {
        
        while (1)
        {
            while (1) {
                char d = p.get();

                if (d == '<')
                    break;
                    
                //content ~= d;
                content.put(d);
            }
            
            p.readtag();
        }
    }
    catch (ReadEnd e) {}
    
    return content.data;
}

// removes special whitespaces...
string remove_ss(string s)
{
    auto spaces = ["\u0020",
    "\u00A0",
    "\u2000",
    "\u2001",
    "\u2002",
    "\u2003",
    "\u2004",
    "\u2005",
    "\u2006",
    "\u2007",
    "\u2008",
    "\u2009",
    "\u200A",
    "\u200B",
    "\u202F",
    "\u205F",
    "\u3000"];
    
    foreach (space; spaces)
    {
        replace(s, space, " ");
    }
    
    return s;
}

string cs(string s)
{
    s = remove_ss(s);
    auto f = split(s);

    return strip(join(f, " "));
}

string tag_name(string whole_inside_tag) {
    auto f = split(whole_inside_tag);
    return f[0];
}

void main()
{
    string input = cast(string) std.file.read("index.html");

        
    /*
    auto s = DSoup(input);
    auto races = s.find_all("div").filter("id", "statistics").find("table");
    foreach (race;races)
    {
        auto tbls = race.find("table");
        auto info = tbls[0];
        auto result = tbls[1];
        auto results = result.find_all("tbody").find("tr")
        auto winnings = tbls[2]; 
    }

        */
    StopWatch sw;
    sw.start();
    auto m = DSoup(input);
    sw.stop();
    writeln("parse filen tok: ", sw.peek().msecs, " millisekunder...");
    
    
    sw.reset();

    
    sw.start();
    auto a = m.find_all("a", SoupFilter().add("class"));
    sw.stop();
    writeln("finn tags: ", sw.peek().msecs, " millisekunder...");

    //auto n = m.select_tags_with_attr("href", "http://www.vg.no/sport/tipping/");
    
    
    
    
    
    
    //std.file.write("halla.txt", a.pretty_print());
    
    
    
    
    
    
    
    
    
    
    
    /*
    writeln();
    char[] buf;
    stdin.readln(buf);
    */


    //std.file.write("halla1.txt", remove_tags(input));
    
}