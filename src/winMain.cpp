#include <windows.h>
#include <string>

#ifndef _MAX_PATH
#define _MAX_PATH 1024
#endif

int GameMain(int argc, char* argv[]);

int CALLBACK WinMain(HINSTANCE /*hInstance*/,  HINSTANCE /*hPrevInstance*/,
                     LPSTR lpCmdLine,  int /*nCmdShow*/)
{
    int    argc;
    char** argv;

    char*  arg;
    int    index;
    int    result;

    // count the arguments

    argc = 1;
    arg  = lpCmdLine;

    while (arg[0] != 0)
    {
        while (arg[0] != 0 && arg[0] == ' ')
        {
            arg++;
        }

        if (arg[0] != 0)
        {
            argc++;
            while (arg[0] != 0 && arg[0] != ' ')
            {
                arg++;
            }
        }
    }

    // tokenize the arguments

    argv = (char**)malloc(argc * sizeof(char*));

    arg = lpCmdLine;
    index = 1;

    while (arg[0] != 0)
    {
        while (arg[0] != 0 && arg[0] == ' ')
        {
            arg++;
        }
        if (arg[0] != 0)
        {
            argv[index] = arg;
            index++;

            while (arg[0] != 0 && arg[0] != ' ')
            {
                arg++;
            }

            if (arg[0] != 0)
            {
                arg[0] = 0;
                arg++;
            }
        }
    }

    // put the program name into argv[0]

    wchar_t filename[_MAX_PATH];

    GetModuleFileName(NULL, filename, _MAX_PATH);
    std::string fileName(filename, filename + wcslen(filename));
    argv[0] = &fileName[0];

    // call the user specified main function

    result = GameMain(argc, argv);

    free(argv);
    return result;
}
