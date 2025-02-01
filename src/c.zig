const builtin = @import("builtin");

pub usingnamespace @cImport({
    if (!builtin.is_test) {
        @cDefine("SDL_MAIN_USE_CALLBACKS", {}); // use the callbacks instead of main()
        @cInclude("SDL3/SDL.h");
        @cInclude("SDL3/SDL_main.h");

        @cDefine("STB_IMAGE_IMPLEMENTATION", {});
        @cDefine("STBI_ONLY_PNG", {});
        @cInclude("stb_image.h");
    }
});
