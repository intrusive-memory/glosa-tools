import GlosaCore
import Testing

/// glosa-tools reads notation 2.0 shots, including the `id` key added in
/// glosa-av 0.10.0. Model-free and file-free: the note text is parsed in memory.
@Suite("Shot id, notation 2.0")
struct ShotIDNotation2Tests {

  /// A multi-line 2.0 note, as written inside a Fountain `[[ ]]` note.
  private let note = """
    {"shot": {
      "id": "panel-01",
      "prompt": "A lighthouse keeper climbs the spiral stair at dusk",
      "style": "ink wash"
    }}
    """

  @Test("A multi-line 2.0 shot with id is read, with its id and prompt")
  func multiLineShotWithIDIsRead() throws {
    let result = GlosaParser().parseFountainWithDiagnostics(notes: [note])
    let shot = try #require(result.score.shots.first)
    #expect(result.score.shots.count == 1)
    #expect(shot.id == "panel-01")
    #expect(shot.prompt == "A lighthouse keeper climbs the spiral stair at dusk")
  }

  @Test("A 2.0 shot without id reads a nil id")
  func shotWithoutIDHasNilID() throws {
    let result = GlosaParser().parseFountainWithDiagnostics(
      notes: [#"{"shot": {"prompt": "p"}}"#])
    let shot = try #require(result.score.shots.first)
    #expect(shot.id == nil)
    #expect(shot.prompt == "p")
  }
}
