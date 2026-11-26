// Run: groovy ci/tests/pipelineUtilsTest.groovy
def utils = new GroovyShell().evaluate(new File('ci/pipelineUtils.groovy'))
def shaA = 'a' * 40
def shaB = 'b' * 40
assert utils.requireRevision(shaA.toUpperCase()) == shaA
for (bad in [null, '', 'abc', 'g' * 40, 'a' * 39, 'a' * 41]) {
    try { utils.requireRevision(bad); assert false : "accepted revision: $bad" }
    catch (IllegalArgumentException expected) { }
}
assert utils.requireRepository('https://github.com/roye-b/jellyfin.git')
for (bad in ['http://github.com/a/b', 'https://evil.example/a/b', 'https://github.com/a/b;rm -rf /']) {
    try { utils.requireRepository(bad); assert false : "accepted URL: $bad" }
    catch (IllegalArgumentException expected) { }
}
def a = utils.resourceName('jellyfin', 'folder/team-one/long-job-' + 'x' * 200, '123')
def b = utils.resourceName('jellyfin', 'folder/team-two/long-job-' + 'x' * 200, '123')
assert a.length() <= 63
assert a ==~ /[a-z0-9][a-z0-9-]*/
assert a != b
assert a == utils.resourceName('jellyfin', 'folder/team-one/long-job-' + 'x' * 200, '123')
for (args in [['Bad!', 'job', '1'], ['ok', '', '1'], ['ok', 'job', 'not-a-number']]) {
    try { utils.resourceName(*args); assert false : "accepted resource: $args" }
    catch (IllegalArgumentException expected) { }
}
def m = utils.buildManifest(shaA, shaB, shaA, 'folder/job', '123', 'jellyfin-ci:123')
assert m.serverCommit == shaB && m.schemaVersion == 1 && m.imageTag == 'jellyfin-ci:123'
println 'PASS: revision/repository rejection, long names, distinct identities, manifest'
