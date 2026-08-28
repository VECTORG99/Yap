import os
import json
import yap
from unittest.mock import patch, mock_open

def test_cargar_perfil_not_exists():
    with patch("os.path.exists", return_value=False):
        assert yap.cargar_perfil() is None

def test_cargar_perfil_exists():
    mock_data = '{"nombre": "Estudiante", "onboarding_completed": true}'
    with patch("os.path.exists", return_value=True):
        with patch("builtins.open", mock_open(read_data=mock_data)):
            perfil = yap.cargar_perfil()
            assert perfil["nombre"] == "Estudiante"
            assert perfil["onboarding_completed"] is True

@patch("builtins.print")
@patch("sys.stdout.write")
@patch("yap.guardar_perfil")
@patch("builtins.input", side_effect=["", "", "", "Juan"])
def test_run_onboarding(mock_input, mock_guardar, mock_write, mock_print):
    perfil = yap.run_onboarding()
    assert perfil["nombre"] == "Juan"
    assert perfil["onboarding_completed"] is True
    mock_guardar.assert_called_once_with(perfil)
