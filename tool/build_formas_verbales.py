"""Formas conjugadas de los verbos con seña → su verbo.

    python tool/build_formas_verbales.py            # escribe
    python tool/build_formas_verbales.py --check    # comprueba que está al día

«va», «tiene», «escuché» o «denunció» no son otra palabra: son el verbo con
otra desinencia, y el verbo SÍ tiene seña. Sin esta tabla se deletreaban
cuando el modelo no las llevaba a su verbo (dictada sola, «va» volvía V-A).

Los verbos son los que ya están en el léxico LSB (`aws/lexico_lsb.json`:
catálogo, módulos M1–M4 y diccionarios): no agrega ninguna seña ni palabra al
vocabulario. Solo conjuga lo que existe.

Genera, con el mismo contenido para que servidor y app no se separen:

    aws/formas_verbales.json                         (la lee la Lambda)
    lib/core/domain/services/verb_forms_data.g.dart  (la lee la app)

Una forma entra solo si no se puede confundir con otra palabra: se descartan
las que son palabras función, las que son una seña del léxico por sí mismas,
las que dos verbos comparten y una lista corta de sustantivos y partículas muy
comunes («para», «trata», «prueba», «hace»…). «fue» (ir y ser) o «ira» (el
sustantivo) no están.
"""

from __future__ import annotations

import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEXICO = os.path.join(ROOT, "aws", "lexico_lsb.json")
SALIDA_JSON = os.path.join(ROOT, "aws", "formas_verbales.json")
SALIDA_DART = os.path.join(
    ROOT, "lib", "core", "domain", "services", "verb_forms_data.g.dart")

# Terminan en -ar/-er/-ir y no son verbos.
NO_VERBOS = {
    "ALQUILER", "ANTEAYER", "AZÚCAR", "BACHILLER", "BILLAR", "CARÁCTER",
    "CELULAR", "CÁNCER", "IMPAR", "JAGUAR", "LÍDER", "MALESTAR", "MILITAR",
    "MUJER", "PARTICULAR", "SINGULAR", "TALLER", "AYER", "MAR", "PAR",
    "SER", "REÍR", "ORAR",
}

# Formas que no se llevan al verbo aunque la conjugación las genere: son otra
# palabra de uso común (sustantivo, preposición, expresión de tiempo) y llevarla
# al verbo cambiaría lo que dice la frase.
CONFUNDIBLES = {
    "PARA", "HACE", "TRATA", "TRATO", "PRUEBA", "PRUEBAS", "CURA", "CUENTA",
    "SE", "DE", "DI", "DA_", "FUE", "FUERON", "FUI_", "IRA", "SOY", "SI",
    "MARCHA", "PASO", "PESCA", "TOMO", "SENTIDO", "SUMA", "RESTA", "CORTE",
    "VOTO", "ORDEN", "CANTO", "PINTA", "SALVA", "SIENTE_", "PRESTAMO",
    "ACUERDO", "DEBATE", "CASTIGO", "GRITO", "BAILE", "CAMBIO", "LLEGADA",
    "COPIA", "PRACTICA", "LUCHA", "PROTESTA", "CAZA", "ESPERA", "GANA",
    "ENVIO", "AVISO", "ANOTA", "ARREGLO", "ABUSO", "AUMENTO", "AHORRO",
    "AYUDA", "EXPLICA", "PRESENTE", "SUPERVISA", "ROBO", "PEGA", "GUARDA",
    "CAMBIA_", "RECOGE_", "VISITA", "FILMA", "PREPARA", "CULPA", "OFENDE_",
    "PERDON", "SOLUCION", "MOSTRA", "VALORA_", "TERMINAL", "CUIDADO",
    "CONFIANZA", "TENDERO", "MORDIDA", "PECA", "LLEVA_", "SEMBRADO",
    "PARTICIPE", "DESCANSO", "ESCAPE", "ESCONDE_", "DESEO", "MANEJO",
    "COMPARTE_", "NARRO_", "OLVIDO", "OPINO_", "SALTO", "ANUNCIO", "AVANCE",
    "ORGANIZA_", "ANEXO", "ESCRIBE_", "SEMBRAR_", "SUFRE_", "VIVE_",
    "CREE_", "DECIDE_", "RECIBE_",
}
CONFUNDIBLES = {c for c in CONFUNDIBLES if not c.endswith("_")}

# Verbos con cambio de vocal en la raíz.
E_IE = {"PENSAR", "ENTENDER", "REFERIR", "PREFERIR", "PERDER", "QUERER", "ENTENDER", "EMPEZAR", "DESPERTAR",
        "DEFENDER", "ENCENDER", "SENTAR", "NEGAR", "COMENZAR", "TENDER",
        "APRETAR", "HERVIR", "CERRAR", "ATENDER", "SUSPENDER", "ADVERTIR",
        "DIVERTIR", "ARREPENTIR", "DESCENDER", "TRAPEAR_"}
E_IE_I = {"REFERIR", "PREFERIR", "SENTIR", "HERVIR", "ADVERTIR", "DIVERTIR", "ARREPENTIR",
          "PREFERIR", "MENTIR"}
O_UE = {"COSTAR", "ENCONTRAR", "CONTAR", "PODER", "VOLVER", "RECORDAR", "MOSTRAR", "PROBAR", "ENCONTRAR",
        "CONTAR", "MORDER", "DEVOLVER", "COLGAR", "APROBAR", "SOLTAR",
        "MOVER", "LLOVER", "DEMOSTRAR", "RECORDAR", "ACORDAR", "RESOLVER",
        "ENCONTRAR", "ROGAR"}
O_UE_U = {"DORMIR", "MORIR"}
E_I = {"CORREGIR", "PEDIR", "REPETIR", "SEGUIR", "SERVIR", "VESTIR", "REGIR", "ELEGIR",
       "CONSEGUIR", "IMPEDIR", "DESPEDIR", "FREIR", "FREÍR", "REÍR"}
U_UE = {"JUGAR"}

# Conjugaciones irregulares completas (formas con tilde, se normalizan).
IRREGULARES = {
    "IR": "voy vas va vamos van iba ibas ibamos iban iré irás irá iremos irán "
          "iría irías iríamos irían vaya vayas vayamos vayan fui fuiste fuimos "
          "fuisteis yendo ido ve",
    "HACER": "hago haces hacemos hacen hacía hacías hacíamos hacían hice "
             "hiciste hizo hicimos hicieron haré harás hará haremos harán "
             "haría harías haríamos harían haga hagas hagamos hagan haz "
             "haciendo hecho hecha hechos hechas",
    "TENER": "tengo tienes tiene tenemos tienen tenía tenías teníamos tenían "
             "tuve tuviste tuvo tuvimos tuvieron tendré tendrás tendrá "
             "tendremos tendrán tendría tendrías tendríamos tendrían tenga "
             "tengas tengamos tengan ten teniendo tenido tenida tenidos",
    "VENIR": "vengo vienes viene venimos vienen venía venías veníamos venían "
             "vine viniste vino vinimos vinieron vendré vendrás vendrá "
             "vendremos vendrán vendría vendrían venga vengas vengamos "
             "vengan ven viniendo venido",
    "PODER": "puedo puedes puede podemos pueden podía podías podíamos podían "
             "pude pudiste pudo pudimos pudieron podré podrás podrá podremos "
             "podrán podría podrías podríamos podrían pueda puedas podamos "
             "puedan pudiendo podido",
    "QUERER": "quiero quieres quiere queremos quieren quería querías "
              "queríamos querían quise quisiste quiso quisimos quisieron "
              "querré querrás querrá querremos querrán querría querrían "
              "quiera quieras queramos quieran queriendo querido",
    "SABER": "sabes sabe sabemos saben sabía sabías sabíamos sabían supe "
             "supiste supo supimos supieron sabré sabrás sabrá sabremos "
             "sabrán sabría sabrían sepa sepas sepamos sepan sabiendo sabido",
    "DAR": "doy das da damos dan daba dabas dábamos daban di diste dio "
           "dimos dieron daré darás dará daremos darán daría darían dé des "
           "demos den dando dado",
    "TRAER": "traigo traes trae traemos traen traía traías traíamos traían "
             "traje trajiste trajo trajimos trajeron traeré traerás traerá "
             "traeremos traerán traería traerían traiga traigas traigamos "
             "traigan trayendo traído",
    "OÍR": "oigo oyes oye oímos oyen oía oías oíamos oían oí oíste oyó "
           "oyeron oiré oirá oiría oiga oigas oigamos oigan oyendo oído",
    "VER": "veo ves ve vemos ven veía veías veíamos veían vi viste vio vimos "
           "vieron veré verás verá veremos verán vería verías veríamos verían "
           "vea veas veamos vean viendo visto vista vistos vistas",
    "LEER": "leo lees lee leemos leen leía leías leíamos leían leí leíste "
            "leyó leímos leyeron leeré leerá leería lea leas leamos lean "
            "leyendo leído",
    "CAER": "caigo caes cae caemos caen caía caías caíamos caían caí caíste "
            "cayó cayeron caeré caerá caería caiga caigas caigamos caigan "
            "cayendo caído",
    "DECIR": "digo dices dice decimos dicen decía decías decíamos decían dije "
             "dijiste dijo dijimos dijeron diré dirás dirá diremos dirán "
             "diría dirían diga digas digamos digan di diciendo dicho dicha "
             "dichos dichas",
    "PONER": "pongo pones pone ponemos ponen ponía ponías poníamos ponían "
             "puse pusiste puso pusimos pusieron pondré pondrás pondrá "
             "pondremos pondrán pondría pondrían ponga pongas pongamos "
             "pongan pon poniendo puesto puesta puestos puestas",
    "SALIR": "salgo sales sale salimos salen salía salías salíamos salían "
             "salí saliste salió salieron saldré saldrá saldría saldrían "
             "salga salgas salgamos salgan sal saliendo salido",
    "ADQUIRIR": "adquiero adquieres adquiere adquirimos adquieren adquirí "
                "adquirió adquirieron adquiriré adquiriría adquiera "
                "adquieran adquiriendo adquirido",
    "ANDAR": "anduve anduviste anduvo anduvimos anduvieron anduviera",
    "CONOCER": "conozco conozca conozcas conozcamos conozcan",
    "PERDER": "pierdo pierdes pierde pierden pierda pierdan",
}

TERM = {
    "AR": dict(
        pres="o as a amos áis an", pret="é aste ó amos asteis aron",
        impf="aba abas aba ábamos abais aban",
        fut="aré arás ará aremos aréis arán",
        cond="aría arías aría aríamos aríais arían",
        subj="e es e emos éis en", imps="ara aras ara áramos arais aran",
        imp="a e emos ad en", ger="ando", part="ado ada ados adas"),
    "ER": dict(
        pres="o es e emos éis en", pret="í iste ió imos isteis ieron",
        impf="ía ías ía íamos íais ían",
        fut="eré erás erá eremos eréis erán",
        cond="ería erías ería eríamos eríais erían",
        subj="a as a amos áis an", imps="iera ieras iera iéramos ierais ieran",
        imp="e a amos ed an", ger="iendo", part="ido ida idos idas"),
    "IR": dict(
        pres="o es e imos ís en", pret="í iste ió imos isteis ieron",
        impf="ía ías ía íamos íais ían",
        fut="iré irás irá iremos iréis irán",
        cond="iría irías iría iríamos iríais irían",
        subj="a as a amos áis an", imps="iera ieras iera iéramos ierais ieran",
        imp="e a amos id an", ger="iendo", part="ido ida idos idas"),
}


def sin_tildes(s: str) -> str:
    # La Ñ se conserva: es otra letra.
    s = s.replace("ñ", "\0").replace("Ñ", "\1")
    s = "".join(c for c in unicodedata.normalize("NFD", s)
                if unicodedata.category(c) != "Mn")
    return s.replace("\0", "Ñ").replace("\1", "Ñ").upper()


def _raiz_para(raiz: str, terminacion: str, clase: str) -> str:
    """Ajusta la ortografía de la raíz a la vocal que sigue (c→qu, g→gu…)."""
    t = terminacion[:1]
    if clase == "AR":
        if raiz.endswith("c") and t in "eé":
            return raiz[:-1] + "qu"
        if raiz.endswith("g") and t in "eé":
            return raiz + "u"
        if raiz.endswith("z") and t in "eé":
            return raiz[:-1] + "c"
    else:
        if clase == "IR" and raiz.endswith("gu") and t[:1] in "oa":
            return raiz[:-1]                          # seguir → sigo, siga
        if raiz.endswith("g") and t in "oa":          # coger, exigir → cojo
            return raiz[:-1] + "j"
        if raiz.endswith("c") and t in "oa" and clase in ("ER", "IR"):
            # vencer → venzo; conocer → conozco (irregular, aparte)
            prev = raiz[-2:-1]
            return raiz[:-1] + ("z" if prev not in "aeiou" else "zc")
    return raiz


def _cambio_vocal(raiz: str, vocal: str, nueva: str) -> str:
    i = raiz.rfind(vocal)
    return raiz[:i] + nueva + raiz[i + len(vocal):] if i >= 0 else raiz


# Verbos cuya lista de IRREGULARES ya trae todas sus formas.
COMPLETOS = {"IR", "HACER", "TENER", "VENIR", "PODER", "QUERER", "SABER", "DAR",
             "TRAER", "OÍR", "VER", "LEER", "CAER", "DECIR", "PONER", "SALIR",
             "ADQUIRIR"}
# Verbos formados con otro irregular: OBTENER = OB + TENER.
COMPUESTOS = {"OBTENER": ("ob", "TENER"), "MANTENER": ("man", "TENER"),
              "CONTENER": ("con", "TENER"), "PERTENECER": None}
PARTICIPIOS_IRREGULARES = {
    "ABRIR": "abierto abierta abiertos abiertas",
    "ESCRIBIR": "escrito escrita escritos escritas",
    "MORIR": "muerto muerta muertos muertas",
    "VOLVER": "vuelto vuelta vueltos vueltas",
    "DEVOLVER": "devuelto devuelta devueltos devueltas",
    "IMPRIMIR": "impreso impresa impresos impresas",
    "FREÍR": "frito frita fritos fritas",
}


def conjugar(inf: str) -> set:
    """Formas del verbo [inf] (minúsculas, con tilde)."""
    up = inf.upper()
    formas = set(IRREGULARES.get(up, "").split())
    if up in COMPUESTOS and COMPUESTOS[up]:
        pref, base = COMPUESTOS[up]
        return {pref + f for f in IRREGULARES[base].split()}
    if up in COMPLETOS:
        return formas
    clase = ("IR" if inf.endswith(("ir", "ír")) else
             "ER" if inf.endswith(("er", "ér")) else "AR")
    raiz = inf[:-2]
    uir = inf.endswith("uir") and not inf.endswith(("guir", "quir"))
    enie = raiz.endswith(("ñ", "ll"))
    r_fuerte = r_pret = raiz
    if up in E_IE or up in E_IE_I:
        r_fuerte = _cambio_vocal(raiz, "e", "ie")
    if up in O_UE or up in O_UE_U:
        r_fuerte = _cambio_vocal(raiz, "o", "ue")
    if up in U_UE:
        r_fuerte = _cambio_vocal(raiz, "u", "ue")
    if up in E_I:
        r_fuerte = r_pret = _cambio_vocal(raiz, "e", "i")
    if up in E_IE_I:
        r_pret = _cambio_vocal(raiz, "e", "i")
    if up in O_UE_U:
        r_pret = _cambio_vocal(raiz, "o", "u")
    if uir:
        r_fuerte = raiz + "y"
    T = TERM[clase]

    def add(r: str, t: str):
        formas.add(_raiz_para(r, t, clase) + t)

    for i, t in enumerate(T["pres"].split()):
        add(r_fuerte if i in (0, 1, 2, 5) else raiz, t)
    for i, t in enumerate(T["pret"].split()):
        r = r_pret if clase == "IR" and i in (2, 5) else raiz
        if uir and i in (2, 5):
            r, t = raiz + "y", {"ió": "ó", "ieron": "eron"}.get(t, t)
        elif enie and t in ("ió", "ieron"):
            t = {"ió": "ó", "ieron": "eron"}[t]
        add(r, t)
    for t in T["impf"].split() + T["fut"].split() + T["cond"].split():
        formas.add(raiz + t)
    for i, t in enumerate(T["subj"].split()):
        r = r_fuerte if i in (0, 1, 2, 5) else (
            r_pret if clase == "IR" else raiz)
        add(r, t)
    for t in T["imps"].split():
        r = r_pret if clase == "IR" else raiz
        if uir:
            r, t = raiz + "y", t.replace("ie", "e")
        elif enie:
            t = t.replace("ie", "e")
        formas.add(r + t)
    for i, t in enumerate(T["imp"].split()):
        add(r_fuerte if i in (0, 1, 4) else raiz, t)
    ger = T["ger"]
    if uir:
        formas.add(raiz + "yendo")
    elif enie:
        formas.add(raiz + ger.replace("ie", "e"))
    else:
        formas.add((r_pret if clase == "IR" else raiz) + ger)
    for t in T["part"].split():
        formas.add(raiz + t)
    formas |= set(PARTICIPIOS_IRREGULARES.get(up, "").split())
    return {f for f in formas if len(f) > 1}


def verbos_del_lexico() -> dict:
    """{GLOSA: infinitivo en minúsculas} de los verbos con seña."""
    lex = json.load(open(LEXICO, encoding="utf-8"))["glosas"]
    out = {}
    for glosa, dato in lex.items():
        if not re.fullmatch(r"[A-ZÑÁÉÍÓÚ]*[A-ZÑÁÉÍÓÚ](AR|ER|IR|ÍR)", glosa) \
                and glosa not in ("IR",):
            continue
        if glosa in NO_VERBOS:
            continue
        out[glosa] = glosa.lower()
    return out


SIN_SENA_JSON = os.path.join(ROOT, "assets", "dictionary", "senas_sin_sena.json")
# Claves de «palabras sin seña» que terminan como un infinitivo y no lo son.
NO_VERBOS_SIN_SENA = {"ALQUILER", "FAMILIAR", "LUGAR", "PARTICULAR", "TITULAR",
                      "LLAVER", "RECOCNER", "SIGUIR"}
# Formas de estos verbos que son también un sustantivo o adjetivo de uso
# común («hipoteca», «cita», «ingreso», «completo»): no se llevan al verbo.
SUSTANTIVOS_GEMELOS = {
    "CITA", "CONSULTA", "DENUNCIA", "FIRMA", "ENTREGA", "ESTAFA", "FALTA",
    "CONTACTO", "INICIO", "CONTROL", "PREGUNTA", "REGISTRO", "CAMBIO", "PAGO",
    "ARCHIVO", "ORDEN", "APORTE", "COSTA", "MATRICULA", "HIPOTECA", "DUDA",
    "INGRESO", "FIGURA", "COMPLETO", "COMPLETA", "REPARTO", "CONSERVA",
    "COMUNICADO", "CERTIFICADO", "DECLARADO", "PUBLICADO", "TITULO",
    "SOLICITUD", "CALIFICA", "RENUEVO", "REPRESENTO", "ASUMO", "CUMPLO",
}


def _segura(forma: str) -> bool:
    """Una forma que se puede llevar a su verbo sin cambiar la palabra: no la
    segunda persona («cuentas», «firmas», «pruebas» son sustantivos en plural)
    ni un sustantivo gemelo del verbo («cita», «denuncia», «hipoteca»)."""
    plano = sin_tildes(forma)
    if plano in SUSTANTIVOS_GEMELOS:
        return False
    if forma.endswith(("as", "es")) and not forma.endswith(("adas", "idas")):
        return False
    return True


def _nombre_o_forma(lex: dict) -> tuple:
    glosas_norm = {sin_tildes(g) for g in lex}
    formas_lexico: dict[str, set] = {}
    for g, d in lex.items():
        for f in d.get("formas", []):
            formas_lexico.setdefault(sin_tildes(f), set()).add(g)
    return glosas_norm, formas_lexico


def construir() -> tuple:
    """(formas de verbos con seña, formas de verbos sin seña con descripción)."""
    lex = json.load(open(LEXICO, encoding="utf-8"))["glosas"]
    verbos = verbos_del_lexico()
    glosas_norm, formas_lexico = _nombre_o_forma(lex)
    funcion = set("""EL LA LOS LAS UN UNA UNOS UNAS AL DEL LO DE EN POR PARA CON
        SOBRE ENTRE HASTA DESDE HACIA TRAS ANTE BAJO U QUE SE ME TE NOS LES LE
        SU MIS TUS SUS ES SON ERA ERAN FUE FUERON SER ESTAR ESTA ESTAN HAY
        HABER HA HAN MUY MAS TAN YA PERO SI NO SIN O Y E A MI TU YO EL""".split())
    candidatas: dict[str, set] = {}
    for glosa, inf in verbos.items():
        for forma in conjugar(inf):
            f = sin_tildes(forma)
            if not re.fullmatch(r"[A-ZÑ]{2,}", f):
                continue
            candidatas.setdefault(f, set()).add(glosa)
    tabla = {}
    for forma, lemas in candidatas.items():
        if len(lemas) != 1:
            continue                      # dos verbos la comparten
        lema = next(iter(lemas))
        # Si el léxico ya documenta la forma como de una seña («escuché» es
        # OÍR, «fui» es IR), manda el léxico; si la comparten dos, no se sabe.
        duenos = formas_lexico.get(forma, set())
        if len(duenos) > 1:
            continue
        if duenos:
            lema = next(iter(duenos))
        if (forma in funcion or forma in CONFUNDIBLES
                or forma == sin_tildes(lema) or forma in glosas_norm):
            continue
        tabla[forma] = lema

    # Las formas que el propio léxico documenta para una seña («solicito» es
    # PEDIR, «algunos» es VARIOS): una sola palabra y de un solo dueño.
    # Solo de verbos, y de las formas del catálogo auditado o que empiezan
    # como el verbo: el léxico trae también sinónimos de diccionario
    # («falta» → AUSENTE, «intento» → TRATAR) que no son una conjugación.
    for forma, duenos in formas_lexico.items():
        if (len(duenos) != 1 or not re.fullmatch(r"[A-ZÑ]{3,}", forma)
                or forma in tabla or forma in funcion
                or forma in CONFUNDIBLES or forma in glosas_norm):
            continue
        dueno = next(iter(duenos))
        if dueno not in verbos:
            continue
        if not (lex[dueno].get("catalogo")
                or forma[:3] == sin_tildes(dueno)[:3]):
            continue
        tabla[forma] = dueno

    # Verbos sin seña que la app explica (descripción o equivalencia): su
    # forma conjugada encuentra la misma explicación.
    sin_sena = json.load(open(SIN_SENA_JSON, encoding="utf-8"))
    claves = set(sin_sena["palabras"]) | set(sin_sena["equivalencias"])
    infinitivos = sorted(
        k for k in claves
        if re.fullmatch(r"[A-ZÑ]{3,}(AR|ER|IR)", k)
        and k not in NO_VERBOS_SIN_SENA
        and sin_tildes(k) not in {sin_tildes(v) for v in verbos})
    cand2: dict[str, set] = {}
    for inf in infinitivos:
        for forma in conjugar(inf.lower()):
            if not _segura(forma):
                continue
            f = sin_tildes(forma)
            if re.fullmatch(r"[A-ZÑ]{3,}", f):
                cand2.setdefault(f, set()).add(inf)
    descritas = {}
    for forma, lemas in cand2.items():
        if (len(lemas) != 1 or forma in tabla or forma in claves
                or forma in funcion or forma in CONFUNDIBLES
                or forma in glosas_norm or forma in formas_lexico):
            continue
        descritas[forma] = next(iter(lemas))
    return dict(sorted(tabla.items())), dict(sorted(descritas.items()))


def a_json(tabla: dict, descritas: dict) -> str:
    return json.dumps({
        "_nota": "GENERADO por tool/build_formas_verbales.py desde "
                 "aws/lexico_lsb.json y assets/dictionary/senas_sin_sena.json. "
                 "No editar a mano.",
        "formas": tabla,
        "descritas": descritas}, ensure_ascii=False, indent=0) + "\n"


def a_dart(tabla: dict, descritas: dict) -> str:
    def mapa(nombre: str, datos: dict, doc: str) -> str:
        filas = "".join(f"  '{f}': '{l}',\n" for f, l in datos.items())
        return f"/// {doc}\nconst Map<String, String> {nombre} = {{\n{filas}}};\n"
    return ("// GENERADO por tool/build_formas_verbales.py. No editar a mano.\n\n"
            + mapa("verbFormsData", tabla,
                   "Forma conjugada (sin tildes) → verbo con seña.")
            + "\n"
            + mapa("describedVerbFormsData", descritas,
                   "Forma conjugada (sin tildes) → verbo sin seña que la app "
                   "explica."))


def main() -> int:
    tabla, descritas = construir()
    salidas = {SALIDA_JSON: a_json(tabla, descritas),
               SALIDA_DART: a_dart(tabla, descritas)}
    if "--check" in sys.argv:
        viejas = [r for r, t in salidas.items()
                  if not os.path.exists(r)
                  or open(r, encoding="utf-8").read() != t]
        for r in viejas:
            print(f"desactualizado: {os.path.relpath(r, ROOT)}")
        return 1 if viejas else 0
    for ruta, texto in salidas.items():
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto)
        print("escrito:", os.path.relpath(ruta, ROOT))
    print(f"{len(tabla)} formas de {len(set(tabla.values()))} verbos con seña; "
          f"{len(descritas)} formas de {len(set(descritas.values()))} verbos "
          "sin seña con descripción")
    return 0


if __name__ == "__main__":
    sys.exit(main())
