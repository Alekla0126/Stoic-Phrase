class StoicPhrase < Formula
  desc "Fetches and displays a random Stoic quote with colorful output"
  homepage "https://github.com/Alekla0126/Stoic-Phrase"
  url "https://github.com/Alekla0126/Stoic-Phrase/archive/refs/tags/1.0.0.tar.gz"
  sha256 "9d9a755cf9a1dbb15e8e35709b9384e2aad53d47dbf58c61f8f43d18cc65fecb"
  license "MIT"

  depends_on "curl"
  depends_on "jq"
  depends_on "lolcat"

  def install
    bin.install "stoic-phrase.sh" => "stoic-phrase"
  end

  test do
    output = shell_output("#{bin}/stoic-phrase")
    assert_match /\S+/, output
  end
end

