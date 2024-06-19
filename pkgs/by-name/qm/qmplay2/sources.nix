{
  fetchFromGitHub,
}:

{
  qmplay2 = let
    self = {
      pname = "qmplay2";
      version = "24.05.23";

      src = fetchFromGitHub {
        owner = "zaps166";
        repo = "QMPlay2";
        rev = self.version;
        fetchSubmodules = true;
        hash = "sha256-HFNq/t0lLVVmCR2tebigDg+X5E3s4a9fVgsjioeNzrg=";
      };
    };
  in
    self;
}
