class Essentia < Formula
  desc "Library for audio analysis and audio-based music information retrieval"
  homepage "http://essentia.upf.edu"
  head 'https://github.com/MTG/essentia.git'

  include Language::Python::Virtualenv

  depends_on "pkg-config" => :build
  depends_on "gcc" => :build
  depends_on "eigen"
  depends_on "libyaml"
  depends_on "fftw"
  depends_on "ffmpeg@6"
  depends_on "libsamplerate"
  depends_on "libtag"
  depends_on "chromaprint"
  depends_on "gaia" => :optional
  depends_on "tensorflow" => :optional

  option "without-python", "Build without Python 3.9 support"

  depends_on "python@3.9" if build.with? "python"
  depends_on "numpy" if build.with? "python"

  resource "six" do
    url "https://files.pythonhosted.org/packages/source/s/six/six-1.16.0.tar.gz"
    sha256 "1e61c37477a1626458e36f7b1d82aa5c9b094fa4802892072e49de9c60c4c926" 
  end

  def install

    build_flags = [
      "--mode=release",
      "--with-examples",
      "--with-vamp",
      "--prefix=#{prefix}"
    ]

    if build.with? "gaia"
      build_flags += ["--with-gaia"]
    end

    if build.with? "tensorflow"
      build_flags += ["--with-tensorflow"]
    end
    
    python = Formula["python@3.9"].opt_bin/"python3"

    system python, "waf", "configure", *build_flags
    system python, "waf"
    system python, "waf", "install"

    python_flags = [
      "--mode=release",
      "--only-python",
      "--prefix=#{prefix}"
    ]

    # Adding path to newly installed Essentia
    ENV['PKG_CONFIG_PATH'] = "#{prefix}/lib/pkgconfig:" + ENV['PKG_CONFIG_PATH']

    if build.with? "python"
      
      # 1. Create virtualenv
      venv = virtualenv_create(libexec, python)

      # 2. Install Python resources (six)
      venv.pip_install resources

      # 3. Waf configuration flags
      python_flags = [
        "--python=#{venv.root}/bin/python",
        "--mode=release",
        "--only-python",
        "--prefix=#{prefix}",
        "--python-install-dir=#{venv.site_packages}"
      ]

      # 4. Configure, build and install using venv Python
      system venv.root/"bin/python", "waf", "configure", *python_flags
      system venv.root/"bin/python", "waf"
      system venv.root/"bin/python", "waf", "install"

      # 5. Expose executables (if any)
      bin.install_symlink Dir[libexec/"bin/*"]

      # version = Language::Python.major_minor_version python 
      
      # (site_packages = Formula["python@3.9"].opt_prefix/"lib/python#{version}/site-packages").mkpath
      # pth_contents = "import site; site.addsitedir('#{libexec/site_packages}')\n"
      # (prefix/site_packages/"homebrew-essentia.pth").write pth_contents
      # (site_packages/"homebrew-essentia.pth").write <<~EOS
      #   import site
      #   site.addsitedir("#{libexec}/lib/python#{version}/site-packages")
      # EOS
    end
  end

  test do
    system "#{bin}/essentia_streaming_extractor_music",
           "/System/Library/Sounds/Glass.aiff",
           "Glass.json"

    py_test = <<~EOS
      import essentia.standard as estd
      import essentia.streaming as estr
      estd.MusicExtractor()("/System/Library/Sounds/Glass.aiff")
    EOS

    if build.with? "python"
      system python, "-c", "#{py_test}"
    end
  end
end

