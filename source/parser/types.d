/*
This Source Code Form is subject to the terms of the Mozilla
Public License, v. 2.0. If a copy of the MPL was not distributed
with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

module parser.types;

import std.string;
import std.array;
import std.conv : to;
import std.ascii : isAlpha;
import parser.ast : Node;
import parser.ast : NodeBlock;
import parser.ast : StructTable;
import parser.ast : Generator;
import parser.ast : into;
import parser.parser : Parser;
import lexer.lexer : Lexer;
import std.stdio;
import parser.parser : instanceof;
import llvm.types : LLVMTypeRef;
import parser.ast : aliasTypes;

enum BasicType {
    Bool,
    Char,
    Short,
    Int,
    Long,
    Cent,
    Float,
    Double,

    Ushort,
    Uint,
    Ulong,
    Uchar,
    Ucent,
}

Type getType(string name) {
    switch(name) {
        case "bool": return new TypeBasic("bool");
        case "char": return new TypeBasic("char");
        case "int": return new TypeBasic("int");
        case "wchar":
        case "short": return new TypeBasic("short");
        case "long": return new TypeBasic("long");
        case "float": return new TypeBasic("float");
        case "double": return new TypeBasic("double");
        case "cent": return new TypeBasic("cent");

        case "ubool": return new TypeBasic("ubool");
        case "uint": return new TypeBasic("uint");
        case "uwchar":
        case "ushort": return new TypeBasic("ushort");
        case "ulong": return new TypeBasic("ulong");
        case "uchar": return new TypeBasic("uchar");
        case "ucent": return new TypeBasic("ucent");

        case "alias": return new TypeAlias();
        default: return new TypeStruct(name);
    }
}

class Type {
    Type copy() {assert(0);}

    int getSize() {
        return 0;
    }

    Type check(Type parent) {
        return null;
    }

    override string toString()
    {
        return "SimpleType";
    }
}

class TypeBasic : Type {
    BasicType type;
    private string value;

    this(string value) {
        this.value = value;
        switch(value) {
            case "int":
                type = BasicType.Int; break;
            case "bool":
                type = BasicType.Bool; break;
            case "wchar":
            case "short":
                type = BasicType.Short; break;
            case "long":
                type = BasicType.Long; break;
            case "float":
                type = BasicType.Float; break;
            case "double":
                type = BasicType.Double; break;
            case "char":
                type = BasicType.Char; break;
            case "cent":
                type = BasicType.Cent; break;
            case "uint":
                type = BasicType.Uint; break;
            case "uwchar":
            case "ushort":
                type = BasicType.Ushort; break;
            case "ulong":
                type = BasicType.Ulong; break;
            case "uchar":
                type = BasicType.Uchar; break;
            case "ucent":
                type = BasicType.Ucent; break;
            default: break;
        }
    }

    this(BasicType t) {
        switch(t) {
            case BasicType.Int:
                value = "int"; break;
            case BasicType.Bool:
                value = "bool"; break;
            case BasicType.Short:
                value = "short"; break;
            case BasicType.Long:
                value = "long"; break;
            case BasicType.Float:
                value = "float"; break;
            case BasicType.Double:
                value = "double"; break;
            case BasicType.Char:
                value = "char"; break;
            case BasicType.Cent:
                value = "cent"; break;
            case BasicType.Uint:
                value = "uint"; break;
            case BasicType.Ushort:
                value = "ushort"; break;
            case BasicType.Ulong:
                value = "ulong"; break;
            case BasicType.Uchar:
                value = "uchar"; break;
            case BasicType.Ucent:
                value = "ucent"; break;
            default: break;
        }
        type = t;
    }
    
    override Type copy() {
        return new TypeBasic(this.value);
    }

    override int getSize() {
        switch(type) {
            case BasicType.Bool: return 1;
            case BasicType.Uchar:
            case BasicType.Char: return 8;
            case BasicType.Ushort:
            case BasicType.Short: return 16;
            case BasicType.Uint:
            case BasicType.Float:
            case BasicType.Int: return 32;
            case BasicType.Ulong:
            case BasicType.Double:
            case BasicType.Long: return 64;
            case BasicType.Ucent:
            case BasicType.Cent: return 128;
            default: break;
        }
        return 0;
    }

    bool isFloat() {
        pragma(inline,true);
        return (type == BasicType.Float || type == BasicType.Double);
    }

    override string toString()
    {
        return this.value;
    }
}

class TypePointer : Type {
    Type instance;

    this(Type instance) {this.instance = instance;}

    override Type copy() {
        return new TypePointer(instance.copy());
    }

    override Type check(Type t) {
        pragma(inline,true);
        if(!instance.instanceof!TypeBasic) instance.check(this);
        return null;
    }

    override int getSize() {
        return 8;
    }

    override string toString()
    {
        return instance.toString()~"*";
    }
}

class TypeArray : Type {
    int count;
    Type element;

    this(int count, Type element) {
        this.count = count;
        this.element = element;
    }

    override Type check(Type parent) {
        pragma(inline,true);
        if(!element.instanceof!TypeBasic) element.check(this);
        return null;
    }

    override Type copy() {
        return new TypeArray(this.count,this.element.copy());
    }

    override int getSize() {
        return element.getSize() * count;
    }

    override string toString()
    {
        return element.toString()~"["~to!string(count)~"]";
    }
}

class TypeAlias : Type {
    override Type copy() {
        return new TypeAlias();
    }
}
class TypeVoid : Type {
    override Type copy() {
        return new TypeVoid();
    }

    override int getSize() {
        return 0;
    }

    override string toString()
    {
        return "void";
    }
}
class TypeStruct : Type {
    string name;
    Type[] types;

    this(string name) {this.name = name;}
    this(string name, Type[] types) {this.name = name; this.types = types.dup;}

    override Type copy() {
        Type[] _types;
        for(int i=0; i<types.length; i++) {
            _types ~= types[i].copy();
        }
        return new TypeStruct(name,_types);
    }

    void updateByTypes() {
        this.name = this.name[0..this.name.indexOf('<')]~"<";
        for(int i=0; i<types.length; i++) {
            this.name ~= types[i].toString()~",";
        }
        this.name = this.name[0..$-1]~">";
    }

    override Type check(Type parent) {
        if(name.into(aliasTypes)) {
            Type _t = aliasTypes[name];
            while(_t.toString().into(aliasTypes)) {
                _t = aliasTypes[_t.toString()];
            }
            
            if(parent is null) return _t;

            if(TypePointer tp = parent.instanceof!TypePointer) {
                tp.instance = _t;
            }
            else if(TypeArray ta = parent.instanceof!TypeArray) {
                ta.element = _t;
            }
            else if(TypeConst tc = parent.instanceof!TypeConst) {
                tc.instance = _t;
            }
        }

        return null;
    }

    override int getSize() {
        Type t = this;
        while(t.toString().into(Generator.toReplace)) t = Generator.toReplace[t.toString()];
        if(TypeStruct ts = t.instanceof!TypeStruct) {
            if(ts.types !is null && !ts.name.into(StructTable)) {
                StructTable[ts.name].generateWithTemplate(ts.name[ts.name.indexOf('<')..$],ts.types.dup);
            }
            return StructTable[ts.name].getSize();
        }
        return t.getSize();
    }

    override string toString()
    {
        return name;
    }
}
class TypeFuncArg : Type {
    Type type;
    string name;

    override Type copy() {
        return new TypeFuncArg(type.copy(),name);
    }

    this(Type type, string name) {
        this.type = type;
        this.name = name;
    }
}
class TypeFunc : Type {
    Type main;
    TypeFuncArg[] args;

    override Type copy() {
        TypeFuncArg[] _copied;

        for(int i=0; i<args.length; i++) {
            _copied ~= args[i].copy().instanceof!TypeFuncArg;
        }

        return new TypeFunc(main.copy(),_copied.dup);
    }

    this(Type main, TypeFuncArg[] args) {
        this.main = main;
        this.args = args;
    }

    override int getSize() {
        return 8;
    }

    override string toString()
    {
        return "NotImplemented";
    }
}
class TypeVarArg : Type {}
class TypeMacroArg : Type { int num; this(int num) {this.num = num;} }
class TypeBuiltin : Type { 
    string name;
    Node[] args;
    NodeBlock block;

    this(string name, Node[] args, NodeBlock block) {
        this.name = name; this.args = args.dup;
        this.block = block;
    }
}
class TypeCall : Type {
    string name;
    Node[] args;

    this(string name, Node[] args) {
        this.name = name;
        this.args = args.dup;
    }

    override string toString() {
        return "FuncCall";
    }
}
class TypeAuto : Type {
    override Type copy() {
        return new TypeAuto();
    }

    this() {}
}
class TypeConst : Type {
    Type instance;

    this(Type instance) {
        this.instance = instance;
    }

    override Type copy() {
        return new TypeConst(this.instance.copy());
    }

    override Type check(Type p) {
        this.instance.check(this);
        return null;
    }

    override int getSize() {
        return instance.getSize();
    }

    override string toString() {return "const("~instance.toString()~")";}
}
class TypeLLVM : Type {
    LLVMTypeRef tr;

    this(LLVMTypeRef tr) {
        this.tr = tr;
    }

    override int getSize() {
        return 0; // TODO
    }
}