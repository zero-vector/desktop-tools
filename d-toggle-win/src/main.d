import std.stdio;
import std.process;
import std.algorithm;

import std.string;

//import std.file;
import std.algorithm.comparison;
import std.algorithm.searching;


void main(string[] args) {

    void printHelp() {
        writeln("Window toggle for X.");
        writeln("Usage:");
        writeln("d-toggle-win [window name]");
    }


    if (args.length == 1) {
        writeln("Error: Too few arguments.");
        writeln();
        printHelp();
        return;
    }


    immutable APP_NAME = args[1];

    enum WinState {
        Iconic = "Iconic",
        Normal = "Normal",
    }

    import std.process;
    import std.algorithm.searching;

    string appId;

    {
        auto prcs = execute(["wmctrl", "-l"]);
        auto lines = lineSplitter(prcs.output);
        foreach (l; lines) {
            if (l.indexOf(APP_NAME) > 0) {
                appId = l[0 .. l.indexOf(' ')];
                break;
            }
        }
    }

    if (!appId) {
        writeln(APP_NAME, " not found. Exiting.");
        return;
    }

    writeln("App id = ", appId);

    auto prcs = execute(["xprop", "-id", appId]);
    auto lines = lineSplitter(prcs.output);
    foreach (l; lines) {

        if (l.indexOf("window state:") > 0) {
            auto state = l[l.indexOf(":") + 1 .. $];
            state = strip(state);

            writeln("App state = ", state);

            switch (state) {
            case WinState.Iconic:
                execute(["wmctrl", "-i", "-R", appId]);
                break;

            case WinState.Normal:
                execute(["wmctrl", "-i", "-r", appId, "-b", "toggle,hidden"]);
                break;

            default:
                // Ignore
                break;
            }

            break;
        }
    }

}
