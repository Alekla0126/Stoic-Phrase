class StoicPhrase < Formula
  desc "Shows a Stoic banner and quote in the terminal"
  homepage "https://github.com/Alekla0126/Stoic-Phrase"
  url "https://github.com/Alekla0126/Stoic-Phrase.git",
      tag: "v1.2.0"
  version "1.2.0"
  license "MIT"

  depends_on "curl"
  depends_on "jq"
  depends_on "lolcat"

  def install
    bin.install "stoic-phrase.sh" => "stoic-phrase"
    pkgshare.install "shell/stoic-phrase.sh" => "stoic-phrase.sh"
  end

  def caveats
    <<~EOS
      The first interactive run prompts you for a username and ASCII style.
      If you want Stoic Phrase to appear automatically when a new shell opens,
      run:

        stoic-phrase --enable-startup
    EOS
  end

  test do
    ENV["STOIC_PHRASE_USERNAME"] = "brew"
    ENV["STOIC_PHRASE_STYLE"] = "classic"
    ENV["STOIC_PHRASE_QUOTE"] = "La disciplina de hoy se convierte en libertad mañana."

    output = shell_output("#{bin}/stoic-phrase")
    assert_match "Bienvenido, brew", output
    assert_match "La disciplina de hoy se convierte en libertad mañana.", output
  end
end
