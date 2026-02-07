class Essentia < Formula
  desc "Library for audio analysis and audio-based music information retrieval"
  homepage "http://essentia.upf.edu"
  head 'https://github.com/MTG/essentia.git', branch: 'master'

  include Language::Python::Virtualenv

  depends_on "pkg-config" => :build
  depends_on "gcc" => :build
  depends_on "eigen@3"
  depends_on "libyaml"
  depends_on "fftw"
  depends_on "ffmpeg@6"
  depends_on "libsamplerate"
  depends_on "libtag"
  depends_on "chromaprint"
  depends_on "gaia" => :optional
  depends_on "tensorflow" => :optional
  depends_on "python@3.11"

  option "without-python", "Build without Python bindings"

  def install

    build_flags = [
      "--mode=release",
      "--with-examples",
      "--with-vamp",
      "--prefix=#{prefix}",
    ]

    build_flags += ["--with-gaia"] if build.with? "gaia"
    build_flags += ["--with-tensorflow"] if build.with? "tensorflow"

    # Add explicit Eigen include path
    ENV.append "CPPFLAGS", "-I#{Formula["eigen@3"].opt_include}/eigen3"
    ENV.append "CXXFLAGS", "-std=gnu++17"

    python = Formula["python@3.11"].opt_bin/"python3.11"
    system python, "./waf", "configure", *build_flags
    system python, "./waf"
    system python, "./waf", "install"

    # Adding path to newly installed Essentia
    ENV['PKG_CONFIG_PATH'] = "#{prefix}/lib/pkgconfig:" + ENV['PKG_CONFIG_PATH']

    return if build.without? "python"
      
    # Create virtual environment and install Essentia dependencies (numpy and six)
    venv = virtualenv_create(libexec, python)
    venv.pip_install "numpy"
    venv.pip_install "six"

    # Set PYTHONPATH so waf sees numpy/six
    py_site = libexec/"lib/python#{Language::Python.major_minor_version(python)}/site-packages"
    ENV["PYTHONPATH"] = py_site

    python_flags = [
      "--mode=release",
      "--only-python",
      "--prefix=#{prefix}",
      "--pythondir=#{libexec}/lib/python#{Language::Python.major_minor_version(python)}/site-packages"
    ]

    system python, "./waf", "configure", *python_flags
    system python, "./waf"
    system python, "./waf", "install"

    # Make bindings discoverable automatically by Python
    pth_file = lib/"python#{Language::Python.major_minor_version(python)}/site-packages/homebrew-essentia.pth"
    pth_file.parent.mkpath
    unless pth_file.exist?
      pth_file.write <<~EOS
        import site; site.addsitedir('#{py_site}')
      EOS
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
      python = Formula["python@3.11"].opt_bin/"python3.11"
      system python, "-c", "#{py_test}"
    end
  end
end

