package org.example;

import javafx.application.Application;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.lang.reflect.Modifier;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Initial application checks that do not start the JavaFX toolkit or open a Stage. */
class MainTest {

    @Test
    void mainClassIsAvailableAndIsAJavaFxApplication() throws ClassNotFoundException {
        Class<?> mainClass = Class.forName("org.example.Main", false, getClass().getClassLoader());

        assertTrue(Application.class.isAssignableFrom(mainClass),
                "Main must remain a JavaFX application");
    }

    @Test
    void runtimeUsesJdk27() {
        assertEquals(27, Runtime.version().feature(),
                "Tests must run with JDK 27, matching pom.xml and CI");
    }

    @Test
    void mainMethodHasAValidJavaEntryPointSignature() throws NoSuchMethodException {
        Method mainMethod = Main.class.getDeclaredMethod("main", String[].class);

        // Inspect the entry point without invoking it: invocation would launch JavaFX.
        assertAll(
                () -> assertTrue(Modifier.isPublic(mainMethod.getModifiers())),
                () -> assertTrue(Modifier.isStatic(mainMethod.getModifiers())),
                () -> assertEquals(void.class, mainMethod.getReturnType())
        );
    }
}
