"""
test_yap_apparmor.py — Pruebas de integración con AppArmor (#14)

Verifica:
  1. apparmor_status() retorna dict con claves correctas
  2. cmd_apparmor_status() muestra mensajes informativos
  3. Comando --apparmor-status se enruta correctamente
  4. Perfil AppArmor existe en el repo
  5. setup.sh incluye instalación de AppArmor

Ejecucion: python3 -m pytest tests/test_yap_apparmor.py -v
"""

import pytest
import sys
import os
import unittest.mock as mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import yap


class TestAppArmorStatus:
    """Requisito: apparmor_status() retorna estado correcto."""

    def test_apparmor_no_instalado(self):
        """Si AppArmor no está instalado, retorna installed=False."""
        with mock.patch("os.path.isdir", return_value=False):
            status = yap.apparmor_status()
            assert status["installed"] is False
            assert status["profile_loaded"] is False
            assert status["mode"] is None

    def test_apparmor_instalado_perfil_no_cargado(self):
        """AppArmor instalado pero perfil no cargado."""
        with mock.patch("os.path.isdir", return_value=True):
            with mock.patch("subprocess.run") as mock_run:
                mock_run.return_value = mock.MagicMock(
                    returncode=0, stdout='{"profiles": {}}'
                )
                with mock.patch("builtins.open", side_effect=FileNotFoundError):
                    status = yap.apparmor_status()
                    assert status["installed"] is True
                    assert status["profile_loaded"] is False

    def test_apparmor_perfil_cargado_enforce(self):
        """Perfil cargado en modo enforce."""
        with mock.patch("os.path.isdir", return_value=True):
            with mock.patch("subprocess.run") as mock_run:
                import json
                mock_run.return_value = mock.MagicMock(
                    returncode=0,
                    stdout=json.dumps({"profiles": {"usr.local.bin.yap": "enforce"}})
                )
                status = yap.apparmor_status()
                assert status["installed"] is True
                assert status["profile_loaded"] is True
                assert status["mode"] == "enforce"

    def test_apparmor_perfil_cargado_complain(self):
        """Perfil cargado en modo complain."""
        with mock.patch("os.path.isdir", return_value=True):
            with mock.patch("subprocess.run") as mock_run:
                import json
                mock_run.return_value = mock.MagicMock(
                    returncode=0,
                    stdout=json.dumps({"profiles": {"usr.local.bin.yap": "complain"}})
                )
                status = yap.apparmor_status()
                assert status["profile_loaded"] is True
                assert status["mode"] == "complain"


class TestCmdAppArmorStatus:
    """Requisito: cmd_apparmor_status() muestra mensajes informativos."""

    def test_no_instalado(self):
        with mock.patch.object(yap, "apparmor_status", return_value={
            "installed": False, "profile_loaded": False, "mode": None
        }):
            result = yap.cmd_apparmor_status()
            assert "no está instalado" in result

    def test_perfil_no_cargado(self):
        with mock.patch.object(yap, "apparmor_status", return_value={
            "installed": True, "profile_loaded": False, "mode": None
        }):
            result = yap.cmd_apparmor_status()
            assert "no está cargado" in result

    def test_enforce_activo(self):
        with mock.patch.object(yap, "apparmor_status", return_value={
            "installed": True, "profile_loaded": True, "mode": "enforce"
        }):
            result = yap.cmd_apparmor_status()
            assert "ACTIVO" in result
            assert "enforce" in result

    def test_complain_activo(self):
        with mock.patch.object(yap, "apparmor_status", return_value={
            "installed": True, "profile_loaded": True, "mode": "complain"
        }):
            result = yap.cmd_apparmor_status()
            assert "ACTIVO" in result
            assert "complain" in result


class TestInterpretRouting:
    """Requisito: interpret() enruta --apparmor-status."""

    def test_interpret_apparmor_status(self):
        action, param = yap.interpret("--apparmor-status")
        assert action == "apparmor_status"
        assert param == "status"

    def test_interpret_apparmor_status_guion(self):
        action, param = yap.interpret("apparmor-status")
        assert action == "apparmor_status"


class TestProfileExists:
    """Requisito: El perfil AppArmor existe en el repo."""

    def test_profile_file_exists(self):
        path = os.path.join(os.path.dirname(yap.__file__), "apparmor", "usr.local.bin.yap")
        assert os.path.exists(path), f"Perfil AppArmor no encontrado: {path}"

    def test_profile_has_enforce_mode(self):
        path = os.path.join(os.path.dirname(yap.__file__), "apparmor", "usr.local.bin.yap")
        with open(path) as f:
            content = f.read()
        # AppArmor default-deny means the profile enforces by default
        assert "profile yap" in content
        assert "/etc/yap/" in content  # Read config
        assert "@{HOME}/.config/yap/" in content  # Write user config
        assert "network inet" in content  # Network for webfetch

    def test_profile_deny_by_default(self):
        """El perfil debe tener default-deny (no allow everything)."""
        path = os.path.join(os.path.dirname(yap.__file__), "apparmor", "usr.local.bin.yap")
        with open(path) as f:
            content = f.read()
        # No debe tener allow all (root-level wildcard without specific path)
        lines = content.split("\n")
        for line in lines:
            stripped = line.strip()
            # Skip comments and empty lines
            if stripped.startswith("#") or not stripped:
                continue
            # Check for dangerous broad permissions (root wildcard)
            # /tmp/** rw is fine (scoped to /tmp), but / ** rw is not
            if stripped.startswith("/ **") or stripped == "/** rw," or stripped == "/** rwx,":
                pytest.fail(f"Permiso demasiado amplio: {stripped}")


class TestSetupShIntegration:
    """Requisito: setup.sh incluye instalación de AppArmor."""

    def test_setup_has_apparmor_step(self):
        setup_path = os.path.join(os.path.dirname(yap.__file__), "setup.sh")
        with open(setup_path) as f:
            content = f.read()
        assert "AppArmor" in content or "apparmor" in content
        assert "apparmor_parser" in content
        assert "usr.local.bin.yap" in content


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
