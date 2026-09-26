# -*- coding: utf-8 -*-
"""Pruebas del Wizard Jerárquico y Generación Estructurada de Declaraciones.

Valida la paridad y completitud sintáctica formal en español boliviano
para los 8 contextos del sistema en el backend de AWS Lambda.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402


class HierarchicalWizardStructuredTests(unittest.TestCase):
    def test_uses_structured_detector(self):
        # Se renombro a has_structured_declaration: el nombre anterior
        # coincidia con la variable local del handler y quedaba ensombrecido.
        self.assertTrue(
            L.has_structured_declaration({"declaration": {"context_id": "denuncia_robo"}}))
        self.assertFalse(L.has_structured_declaration({"cards": ["CELULAR"]}))
        self.assertFalse(L.has_structured_declaration({}))

    def test_context_denuncia_robo_theft(self):
        decl = {
            "context_id": "denuncia_robo",
            "hecho": {"tipo": "robo", "accion": "ROBAR", "escapar_actor": "sospechoso"},
            "objetos": [
                {"glosa": "CELULAR", "rol": "robado", "detalles": "celular marca Samsung"},
                {"glosa": "BILLETES", "rol": "robado", "detalles": "dinero en efectivo"},
            ],
            "personas": [
                {
                    "id": "p1",
                    "rol": "sospechoso",
                    "genero": "hombre",
                    "complexion": "alto",
                    "ropa": [
                        {"prenda": "chamarra", "color": "negra"},
                        {"prenda": "pantalón", "color": "azul"},
                    ],
                }
            ],
            "lugar": {"espacio": "calle", "zona": "San Martín"},
            "tiempo": "hoy por la tarde",
            "evidencia": ["FOTOS", "FACTURA"],
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Denuncio el robo de celular marca Samsung, dinero en efectivo.", res)
        self.assertIn("Ocurrió en calle en zona San Martín, hoy por la tarde.", res)
        self.assertIn("El sospechoso se dio a la fuga.", res)
        self.assertIn("Autor / sospechoso:", res)
        self.assertIn("hombre de contextura alta", res)
        self.assertIn("vestía chamarra negra, pantalón azul", res)
        self.assertIn("Cuento con elementos de prueba o respaldo: fotografías, la factura.", res)

    def test_context_denuncia_robo_loss_perder(self):
        decl = {
            "context_id": "denuncia_robo",
            "hecho": {"tipo": "perdida", "accion": "PERDER"},
            "objetos": [
                {"glosa": "CELULAR", "rol": "perdido", "detalles": "celular"},
                {"glosa": "IDENTIDAD", "rol": "documento", "detalles": "cédula de identidad"},
            ],
            "lugar": {"espacio": "mercado", "zona": "La Cancha"},
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("He extraviado o perdido: celular, cédula de identidad.", res)
        self.assertIn("en mercado en zona La Cancha", res)
        self.assertNotIn("sustrajo", res)
        self.assertNotIn("robo", res.lower())

    def test_context_violencia(self):
        decl = {
            "context_id": "violencia",
            "hecho": {"tipo": "violencia_fisica", "accion": "PEGAR"},
            "violencia": {
                "agresor_relacion": "pareja",
                "heridas": "golpes y moretones en los brazos",
                "atencion_medica": True,
                "certificado_forense": True,
                "solicita_medidas_proteccion": True,
                "frecuencia": "recurrente",
            },
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Denuncio agresión física y violencia sufrida.", res)
        self.assertIn("La persona agresora es mi pareja.", res)
        self.assertIn("Presento lesiones: golpes y moretones en los brazos.", res)
        self.assertIn("He recibido o requiero atención médica de urgencia.", res)
        self.assertIn("Cuento con certificado médico forense.", res)
        self.assertIn("Esta situación de agresión ocurre de manera recurrente.", res)
        self.assertIn("Solicito medidas de protección inmediata para salvaguardar mi integridad.", res)

    def test_context_amenaza_digital(self):
        decl = {
            "context_id": "amenaza_digital",
            "hecho": {"tipo": "amenaza_digital", "accion": "AMENAZAR"},
            "amenaza_digital": {
                "medio": "WhatsApp",
                "remitente": "número desconocido",
                "mensajes_guardados": True,
                "capturas_pantalla": True,
                "numero_telefono": "71727374",
            },
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Denuncio la recepción de mensajes hostiles y amenazas a través de medios digitales.", res)
        self.assertIn("Canal utilizado: WhatsApp.", res)
        self.assertIn("Remitente: número desconocido.", res)
        self.assertIn("Número de contacto / remitente: 71727374.", res)
        # Guardar los mensajes y tener capturas son hechos distintos; aquí
        # se declararon los dos, y cada uno se redacta por separado.
        self.assertIn("Guardé los mensajes.", res)
        self.assertIn("Tengo capturas de pantalla de los mensajes.", res)

    def test_context_engano_dinero(self):
        decl = {
            "context_id": "engano_dinero",
            "hecho": {"tipo": "estafa", "accion": "ENGAÑAR"},
            "engano_dinero": {
                "tipo_engano": "estafa con oferta de empleo",
                "monto_aproximado": "2000 Bs",
                "via_pago": "transferencia bancaria QR",
                "destinatario": "María López",
                "tiene_comprobante": True,
            },
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Denuncio un engaño económico / estafa con oferta de empleo.", res)
        self.assertIn("Monto involucrado: 2000 Bs.", res)
        self.assertIn("Medio de pago / transferencia: transferencia bancaria QR.", res)
        self.assertIn("Beneficiario o destinatario del dinero: María López.", res)
        # «Bancario» no se declaró: el comprobante no se califica.
        self.assertIn("Cuento con un comprobante de la transacción.", res)
        self.assertNotIn("bancarios", res)

    def test_context_seguimiento(self):
        decl = {
            "context_id": "seguimiento",
            "procedimiento": {
                "tipo_tramite": "revisión de cuaderno de investigación",
                "numero_caso": "CB-2026-4410",
                "autoridad_destino": "Fiscalía de Cochabamba",
                "accion_solicitada": "solicitar fotocopias legalizadas",
                "proxima_fecha": "el día viernes",
            },
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Solicito información sobre el trámite: revisión de cuaderno de investigación.", res)
        self.assertIn("Número de caso / NUREJ / referencia: CB-2026-4410.", res)
        self.assertIn("Autoridad o despacho: Fiscalía de Cochabamba.", res)
        self.assertIn("Acción o consulta: solicitar fotocopias legalizadas.", res)
        self.assertIn("Fecha programada / retorno: el día viernes.", res)

    def test_context_otro_testimonio(self):
        decl = {
            "context_id": "otro",
            "hecho": {
                "tipo": "testimonio",
                "accion": "OBSERVAR",
                "relato_libre": "Observé un altercado en la esquina de la plaza.",
            },
            "personas": [
                {
                    "id": "p1",
                    "rol": "involucrado",
                    "genero": "hombre",
                    "complexion": "delgado",
                }
            ],
            "necesita_interprete": True,
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Declaración testimonial: Observé un altercado en la esquina de la plaza.", res)
        self.assertIn("Personas observadas:", res)
        self.assertIn("hombre de contextura delgado", res)
        self.assertIn("Solicito asistencia de un intérprete en Lengua de Señas Boliviana (LSB).", res)

    def test_context_identificacion(self):
        decl = {
            "context_id": "identificacion",
            "identificacion_nombre": "Raúl Gutiérrez",
            "identificacion_documento": "5123456 LP",
            "identificacion_contacto": "68012345",
            "identificacion_acompanante": "madre",
            "necesita_interprete": True,
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Datos de identificación:", res)
        self.assertIn("Nombre completo: Raúl Gutiérrez.", res)
        self.assertIn("Documento de identidad: 5123456 LP.", res)
        # Nadie dijo WhatsApp: el número es solo un teléfono de contacto.
        self.assertIn("Teléfono de contacto: 68012345.", res)
        self.assertNotIn("WhatsApp", res)
        self.assertIn("Acompañante: madre.", res)
        self.assertIn("Comunico que soy una persona sorda y requiero comunicación escrita o intérprete oficial de LSB.", res)

    def test_context_preguntas(self):
        decl = {
            "context_id": "preguntas",
            "consulta": {
                "pregunta_principal": "¿A qué hora atiende la ventanilla única?",
                "lugar_consulta": "Palacio de Justicia",
                "autoridad_consulta": "encargado de plataforma",
                "tema_consulta": "presentación de memorial",
                "tiempo_espera": "15 minutos",
            },
        }
        res = L.generate_structured_sentence(decl)
        self.assertIn("Consulta ciudadana: ¿A qué hora atiende la ventanilla única?", res)
        self.assertIn("Lugar o institución de referencia: Palacio de Justicia.", res)
        self.assertIn("Funcionario / autoridad por quien se consulta: encargado de plataforma.", res)
        self.assertIn("Materia o tema: presentación de memorial.", res)
        self.assertIn("Tiempo estimado o plazo informado: 15 minutos.", res)


if __name__ == "__main__":
    unittest.main()
