import Foundation
@testable import Moblin
import Testing

private func makeSettings(capitalLetters: Bool = false,
                          links: Bool = false,
                          lettersAndNumbers: Bool = false) -> VkVideoLiveChatSettings
{
    VkVideoLiveChatSettings(mode: VkVideoLiveChatMode(general: VkVideoLiveChatModeGeneral(
        is_caps_prohibited: capitalLetters,
        is_links_prohibited: links,
        is_ru_en_numbers: lettersAndNumbers
    )))
}

private func makeOnlySmilesSettings() -> VkVideoLiveChatSettings {
    VkVideoLiveChatSettings(mode: VkVideoLiveChatMode(only_smiles: VkVideoLiveChatModeOnlySmiles()))
}

private func encoded(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try! String(bytes: encoder.encode(value), encoding: .utf8)!
}

private func general(capitalLetters: Bool = false,
                     links: Bool = false,
                     lettersAndNumbers: Bool = false) -> String
{
    """
    {"general":{"is_caps_prohibited":\(capitalLetters),"is_links_prohibited":\(links),\
    "is_ru_en_numbers":\(lettersAndNumbers)}}
    """
}

struct VkVideoLiveChatSettingsSuite {
    struct ModeCase: CustomTestStringConvertible {
        let testDescription: String
        let settings: VkVideoLiveChatSettings
        let expected: String

        init(_ description: String, _ settings: VkVideoLiveChatSettings, _ expected: String) {
            testDescription = description
            self.settings = settings
            self.expected = expected
        }
    }

    @Test(arguments: [
        ModeCase("No mode", VkVideoLiveChatSettings(), general(capitalLetters: true)),
        ModeCase("No restrictions", makeSettings(), general(capitalLetters: true)),
        ModeCase("Links prohibited", makeSettings(links: true), general(capitalLetters: true, links: true)),
        ModeCase("Only smiles", makeOnlySmilesSettings(), general(capitalLetters: true)),
    ])
    func prohibitingCapitalLetters(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setCapitalLettersProhibited(true)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test(arguments: [
        ModeCase("No mode", VkVideoLiveChatSettings(), "{}"),
        ModeCase("Only capital letters prohibited", makeSettings(capitalLetters: true), "{}"),
        ModeCase(
            "Links prohibited too",
            makeSettings(capitalLetters: true, links: true),
            general(links: true)
        ),
    ])
    func allowingCapitalLetters(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setCapitalLettersProhibited(false)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test(arguments: [
        ModeCase("No mode", VkVideoLiveChatSettings(), general(links: true)),
        ModeCase("Capital letters prohibited",
                 makeSettings(capitalLetters: true),
                 general(capitalLetters: true, links: true)),
        ModeCase("Only smiles", makeOnlySmilesSettings(), general(links: true)),
    ])
    func prohibitingLinks(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setLinksProhibited(true)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test(arguments: [
        ModeCase("Only links prohibited", makeSettings(links: true), "{}"),
        ModeCase("Letters and numbers only too",
                 makeSettings(links: true, lettersAndNumbers: true),
                 general(lettersAndNumbers: true)),
    ])
    func allowingLinks(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setLinksProhibited(false)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test(arguments: [
        ModeCase("No mode", VkVideoLiveChatSettings(), general(lettersAndNumbers: true)),
        ModeCase(
            "Links prohibited",
            makeSettings(links: true),
            general(links: true, lettersAndNumbers: true)
        ),
        ModeCase("Only smiles", makeOnlySmilesSettings(), general(lettersAndNumbers: true)),
    ])
    func allowingLettersAndNumbersOnly(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setLettersAndNumbersOnly(true)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test(arguments: [
        ModeCase("Only letters and numbers only", makeSettings(lettersAndNumbers: true), "{}"),
        ModeCase("Capital letters prohibited too",
                 makeSettings(capitalLetters: true, lettersAndNumbers: true),
                 general(capitalLetters: true)),
    ])
    func allowingAllCharacters(testCase: ModeCase) {
        var settings = testCase.settings
        settings.setLettersAndNumbersOnly(false)
        #expect(encoded(settings.mode) == testCase.expected)
    }

    @Test
    func missingRequiredFieldsAreFilled() {
        var settings = VkVideoLiveChatSettings()
        settings.fillRequiredFields()
        #expect(encoded(settings) == """
        {"allow_access":"any","allow_access_after":0,"any_message_timeout":0,"follow_alert":true,\
        "same_message_timeout":0,"subscription_alert":true}
        """)
    }

    @Test
    func existingRequiredFieldsAreKept() {
        var settings = VkVideoLiveChatSettings(allow_access: "subscribers",
                                               allow_access_after: 600,
                                               any_message_timeout: 30,
                                               follow_alert: false,
                                               same_message_timeout: 60,
                                               subscription_alert: false)
        settings.fillRequiredFields()
        #expect(encoded(settings) == """
        {"allow_access":"subscribers","allow_access_after":600,"any_message_timeout":30,\
        "follow_alert":false,"same_message_timeout":60,"subscription_alert":false}
        """)
    }
}
