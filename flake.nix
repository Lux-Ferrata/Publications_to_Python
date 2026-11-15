{
  description = "Publications to Python";
  # This flake is meant to mirror my personal blogs, to allow
  # me to experiment with things before publishing them.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python314;

        mcpyrate = python.pkgs.buildPythonPackage rec {
          pname = "mcpyrate";
          version = "4.2.0";
          pyproject = true;
          src = python.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "b6b7f3efb205e34aa77ac26715c380882d371ed123b0a508447534f451a3d558";
          };
          build-system = [ python.pkgs.pdm-backend ];
          dependencies = [ python.pkgs.colorama ];
          pythonImportsCheck = [ "mcpyrate" ];
          doCheck = false;
        };

        tnTikz = python.pkgs.toPythonModule (
          pkgs.runCommand "tn-tikz" { } ''
            install -Dm644 ${./flake_utils/tn_tikz.py} $out/${python.sitePackages}/tn_tikz.py
          ''
        );
        tex = pkgs.texliveBasic.withPackages (
          ps: with ps; [
            standalone
            pgf
            tikz-cd
            amsfonts
          ]
        );

        pythonEnv = python.withPackages (
          ps: with ps; [
            # Jupyter
            jupyter
            ipykernel
            nbclient
            nbformat
            pyyaml

            # Scientific Python
            numpy
            scipy
            numba
            sympy
            matplotlib
            pytest
            hypothesis
            pandas
            seaborn
            scikit-learn
            torch
            jax
            jaxlib
            qutip
            qiskit
            qiskit-aer

            # visualization
            plotly
            manim

            # other tools
            bash-kernel
            mcpyrate
            tnTikz
          ]
        );

        kernelspec = name: spec: pkgs.writeTextDir "kernels/${name}/kernel.json" (builtins.toJSON spec);
        kernels = pkgs.symlinkJoin {
          name = "publications-jupyter-kernels";
          paths = [
            (kernelspec "python3" {
              display_name = "Python ${python.version}";
              language = "python";
              argv = [
                "${pythonEnv}/bin/python"
                "-m"
                "ipykernel_launcher"
                "--ext=tn_tikz"
                "-f"
                "{connection_file}"
              ];
            })
            (kernelspec "bash" {
              display_name = "Bash";
              language = "bash";
              argv = [
                "${pythonEnv}/bin/python"
                "-m"
                "bash_kernel"
                "-f"
                "{connection_file}"
              ];
            })
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pythonEnv
            pkgs.pyrefly
            pkgs.git
            tex
            pkgs.pdf2svg
          ];
          JUPYTER_PATH = "${kernels}";
        };
      }
    );
}
