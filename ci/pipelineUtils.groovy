import java.security.MessageDigest

String requireRevision(String value) {
    if (value == null || !(value ==~ /(?i)[0-9a-f]{40}/)) {
        throw new IllegalArgumentException('Revision must be a full 40-character Git SHA')
    }
    return value.toLowerCase(Locale.ROOT)
}

String requireRepository(String value) {
    if (value == null || !(value ==~ /https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(?:\.git)?/)) {
        throw new IllegalArgumentException('Only a valid HTTPS GitHub repository URL is allowed')
    }
    return value
}

String resourceName(String prefix, String jobIdentity, String buildNumber) {
    if (prefix == null || !(prefix ==~ /[a-z][a-z0-9-]{0,19}/)) {
        throw new IllegalArgumentException('Invalid resource prefix')
    }
    if (jobIdentity == null || !jobIdentity.trim() || buildNumber == null ||
        !(buildNumber ==~ /[1-9][0-9]{0,9}/)) {
        throw new IllegalArgumentException('Invalid job identity or build number')
    }
    byte[] bytes = MessageDigest.getInstance('SHA-256').digest(
        jobIdentity.getBytes('UTF-8'))
    String hash = bytes[0..5].collect { String.format('%02x', it & 0xff) }.join('')
    String clean = jobIdentity.toLowerCase(Locale.ROOT)
        .replaceAll(/[^a-z0-9]+/, '-').replaceAll(/^-+|-+$/, '')
    if (!clean) clean = 'job'
    int available = 63 - prefix.length() - buildNumber.length() - hash.length() - 3
    if (available < 1) throw new IllegalArgumentException('Resource name too long')
    clean = clean.take(available).replaceAll(/-+$/, '')
    if (!clean) clean = 'j'
    return "${prefix}-${clean}-${hash}-${buildNumber}"
}

Map buildManifest(String assessmentSha, String serverSha, String webSha,
                  String jobIdentity, String buildNumber, String imageTag) {
    if (imageTag == null || !(imageTag ==~ /[a-z0-9][a-z0-9._:-]{0,127}/)) {
        throw new IllegalArgumentException('Invalid image tag')
    }
    return [
        schemaVersion: 1,
        assessmentCommit: requireRevision(assessmentSha),
        serverCommit: requireRevision(serverSha),
        webCommit: requireRevision(webSha),
        jobIdentity: jobIdentity,
        buildNumber: buildNumber,
        imageTag: imageTag
    ]
}

return this
