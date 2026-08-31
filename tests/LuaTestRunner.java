import java.io.IOException;
import java.io.Reader;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;
import zombie.sandbox.CustomSandboxOptions;

public final class LuaTestRunner {
    private LuaTestRunner() {
    }

    private static LuaClosure compile(Path path, KahluaTable environment) throws IOException {
        try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
            return LuaCompiler.loadis(reader, path.toString(), environment);
        }
    }

    private static void execute(Path path, KahluaTable environment, KahluaThread thread)
            throws IOException {
        LuaClosure closure = compile(path, environment);
        thread.call(closure, null, null, null);
    }

    private static void validateSandboxOptions(Path path) throws Exception {
        CustomSandboxOptions options = new CustomSandboxOptions();
        Method readFile = CustomSandboxOptions.class.getDeclaredMethod("readFile", String.class);
        readFile.setAccessible(true);
        boolean parsed = (Boolean) readFile.invoke(options, path.toString());
        if (!parsed) {
            throw new IllegalStateException("Build 42.20 rejected sandbox-options.txt");
        }

        Field optionsField = CustomSandboxOptions.class.getDeclaredField("options");
        optionsField.setAccessible(true);
        int optionCount = ((List<?>) optionsField.get(options)).size();
        if (optionCount != 16) {
            throw new IllegalStateException(
                "Build 42.20 parsed " + optionCount + " sandbox options instead of 16"
            );
        }
        System.out.println("Build 42.20 parsed all 16 sandbox options.");
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected the Changing Skies repository root.");
        }

        Path repository = Paths.get(args[0]).toAbsolutePath().normalize();
        Path luaRoot = repository.resolve(
            "Contents/mods/ChangingSkies/42.20/media/lua/server/ChangingSkies"
        );
        validateSandboxOptions(repository.resolve(
            "Contents/mods/ChangingSkies/42.20/media/sandbox-options.txt"
        ));
        String[] executableModules = {
            "Constants.lua",
            "Log.lua",
            "Settings.lua",
            "State.lua",
            "Temperature.lua",
            "Weather.lua",
            "Thunder.lua",
            "SnowDiagnostics.lua"
        };

        J2SEPlatform platform = J2SEPlatform.getInstance();
        KahluaTable environment = platform.newEnvironment();
        KahluaThread thread = new KahluaThread(System.out, platform, environment);

        for (String module : executableModules) {
            execute(luaRoot.resolve(module), environment, thread);
        }

        // Bootstrap depends on game-owned globals, so compile it for syntax without executing it.
        compile(luaRoot.resolve("Bootstrap.lua"), environment);
        execute(repository.resolve("tests/ChangingSkiesTests.lua"), environment, thread);
    }
}
