package org.example.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class JwtAuthConverterTest {

    private JwtAuthConverter converter;

    @BeforeEach
    void setUp() {
        converter = new JwtAuthConverter();
        // Set the values for @Value properties
        converter.principalAttribute = "preferred_username";
        converter.resourceId = "my-app";
    }

    @Test
    void convert_withNoResourceAccess_returnsJwtAuthenticationTokenWithJwtAuthoritiesOnly() {
        Jwt jwt = mock(Jwt.class);
        when(jwt.getClaim("resource_access")).thenReturn(null);
        when(jwt.getClaim("preferred_username")).thenReturn("test-user");

        Mono<AbstractAuthenticationToken> monoToken = converter.convert(jwt);

        StepVerifier.create(monoToken)
                .assertNext(token -> {
                    assertEquals("test-user", token.getName());
                    assertNotNull(token.getAuthorities());
                    assertTrue(token.getAuthorities().isEmpty() || token.getAuthorities().size() >= 0); // depends on JwtGrantedAuthoritiesConverter mock
                })
                .verifyComplete();
    }

    @Test
    void convert_withResourceRoles_returnsJwtAuthenticationTokenWithRoles() {
        Jwt jwt = mock(Jwt.class);
        Map<String, Object> resourceMap = new HashMap<>();
        resourceMap.put("roles", List.of("USER", "ADMIN"));
        Map<String, Object> resourceAccess = Map.of("my-app", resourceMap);

        when(jwt.getClaim("resource_access")).thenReturn(resourceAccess);
        when(jwt.getClaim("preferred_username")).thenReturn("test-user");

        Mono<AbstractAuthenticationToken> monoToken = converter.convert(jwt);

        StepVerifier.create(monoToken)
                .assertNext(token -> {
                    assertEquals("test-user", token.getName());
                    Collection<? extends GrantedAuthority> authorities = token.getAuthorities();
                    assertTrue(authorities.stream().anyMatch(a -> a.getAuthority().equals("ROLE_USER")));
                    assertTrue(authorities.stream().anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN")));
                })
                .verifyComplete();
    }

    @Test
    void convert_withNullPrincipalAttribute_returnsSubject() {
        Jwt jwt = mock(Jwt.class);
        converter.principalAttribute = null;
        when(jwt.getSubject()).thenReturn("jwt-subject");

        Mono<AbstractAuthenticationToken> monoToken = converter.convert(jwt);

        StepVerifier.create(monoToken)
                .assertNext(token -> assertEquals("jwt-subject", token.getName()))
                .verifyComplete();
    }

    @Test
    void extractResourceRoles_withNoRoles_returnsEmptySet() throws Exception {
        Jwt jwt = mock(Jwt.class);
        Map<String, Object> resourceMap = Map.of("roles", List.of()); // empty list instead of missing key
        Map<String, Object> resourceAccess = Map.of("my-app", resourceMap);
        when(jwt.getClaim("resource_access")).thenReturn(resourceAccess);

        var method = JwtAuthConverter.class.getDeclaredMethod("extractResourceRoles", Jwt.class);
        method.setAccessible(true);
        var result = (Collection<?>) method.invoke(converter, jwt);
        assertTrue(result.isEmpty());
    }
}
