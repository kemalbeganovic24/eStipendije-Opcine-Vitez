package org.example.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import static org.junit.jupiter.api.Assertions.*;
@Tag("integration")
class DatabaseConnectionTest {

    @Test
    void shouldConnectToAivenDatabase() throws Exception {

        try (Connection connection =
                     DatabaseConnection.getConnection()) {

            assertNotNull(connection);
            assertFalse(connection.isClosed());

            try (PreparedStatement statement =
                         connection.prepareStatement(
                                 "SELECT COUNT(*) FROM competitions"
                         );
                 ResultSet result = statement.executeQuery()) {

                assertTrue(result.next());
                assertTrue(result.getInt(1) >= 1);
            }
        }
    }
}
