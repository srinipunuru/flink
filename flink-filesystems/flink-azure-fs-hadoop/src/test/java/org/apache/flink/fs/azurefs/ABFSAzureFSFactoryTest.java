package org.apache.flink.fs.azurefs;

import org.apache.flink.configuration.Configuration;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

import java.net.URI;
import java.util.Arrays;
import java.util.List;

/** Tests for the ABFSAzureFSFactory. */
@RunWith(Parameterized.class)
public class ABFSAzureFSFactoryTest {
    @Parameterized.Parameter public String scheme;

    @Parameterized.Parameters(name = "Scheme = {0}")
    public static List<String> parameters() {
        return Arrays.asList("abfs", "abfss");
    }

    @Rule public final ExpectedException exception = ExpectedException.none();

    private AbstractAzureFSFactory getFactory(String scheme) {
        return scheme.equals("abfs") ? new ABFSAzureFSFactory() : new SecureABFSAzureFSFactory();
    }

    @Test
    public void testNullFsURI() throws Exception {
        URI uri = null;
        AbstractAzureFSFactory factory = getFactory(scheme);

        exception.expect(NullPointerException.class);
        exception.expectMessage("passed file system URI object should not be null");

        factory.create(uri);
    }

    @Test
    public void testCreateFsWithMissingAuthority() throws Exception {
        String uriString = String.format("%s:///my/path", scheme);
        final URI uri = URI.create(uriString);

        exception.expect(IllegalArgumentException.class);
        exception.expectMessage(String.format("%s has invalid authority.", uriString));

        AbstractAzureFSFactory factory = getFactory(scheme);
        factory.configure(new Configuration());
        factory.create(uri);
    }
}
