/*
This Source Code Form is subject to the terms of the Mozilla
Public License, v. 2.0. If a copy of the MPL was not distributed
with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

import std.stdio;
import lexer.lexer;
import std.conv : to;
import compiler;
import core.stdc.stdlib : exit;
import parser.parser;
import llvm;

string[] files;
string outfile;

version(Win64) {
	string outtype = "win64";
}

else version(Win32) {
	string outtype = "win32";
}

else version(linux) {
	version(X86_64) {
		string outtype = "linux-x86_64";
	}
	else version(X86) {
		string outtype = "linux-i686";
	}
	else version(AArch64) {
		string outtype = "aarch64";
	}
	else version(ARM) {
		string outtype = "armv7";
	}
	else string outtype = "unknown-linux";
}

else string outtype = "unknown";

struct CompOpts {
	bool noPrelude = false;
	bool debugMode = false;
	bool emit_llvm = false;
	string linkparams = "";
	bool onlyObject = false;
	bool noEntry = false;
	bool noStd = false;
	bool printAll = false;
	int optimizeLevel = 0;
    bool isPIE = false;
    bool noPIE = false;
	bool isPIC = false;
	bool runtimeChecks = true;
	bool disableWarnings = false;
}

CompOpts analyzeArgs(string[] args) {
	int idx = 0;
	CompOpts opts;
	while(idx<args.length) {
		string currCommand = args[idx];
		switch(currCommand) {
			case "-o": case "--out": outfile = args[idx+1]; idx += 1; break;
			case "-np": case "--noPrelude": opts.noPrelude = true; break;
			case "-d": case "--debug": opts.debugMode = true; break;
			case "-t": case "--type": outtype = args[idx+1]; idx += 1; break;
			case "-pa": case "--printAll": opts.printAll = true; break;
			case "-el": case "--emit-llvm":
			case "-emit-llvm": // Compatible with the same option from clang
				opts.emit_llvm = true; break;
            case "-fPIE": opts.isPIE = true; break;
			case "-fPIC": opts.isPIC = true; break;
			case "-l": case "--library":
			  opts.linkparams ~= "-l"~args[idx+1]~" "; idx += 1; break;
			case "-c": opts.onlyObject = true; break;
			case "-ne": case "--noEntry": opts.noEntry = true; break;
			case "-ns": case "--noStd": opts.noStd = true; break;
                case "-nopie": opts.noPIE = true; break;
			case "-ol": case "--optimization-level":
			case "-O": // Compatible with the same option from clang
				opts.optimizeLevel = to!int(args[idx+1]); idx += 1; break;
			case "-s": case "--shared":
				opts.linkparams ~= "-shared "; break;
			case "-rco": case "--runtimeChecksOff":
				opts.runtimeChecks = false;
				break;
			case "-dw": case "--disableWarnings":
				opts.disableWarnings = true;
				break;
			default:
				if(currCommand[0] == '-') {
					opts.linkparams ~= currCommand~" "; idx += 1;
				}
				else files ~= args[idx];
				break;
		}
		idx += 1;
	}
	return opts;
}

void main(string[] args)
{
	if(args.length==1) {
		writeln("No compilation files were found!");
		exit(1);
	}
	CompOpts o = analyzeArgs(args[1..$]);
	Compiler compiler = new Compiler(outfile,outtype,o);
	compiler.compileAll();
}
