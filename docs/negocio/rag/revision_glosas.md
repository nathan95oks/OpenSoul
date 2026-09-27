# Revisión de glosas del corpus RAG

Generado por `tool/rag_revisar_glosas.py`. No editar a mano.

Bedrock traduce las glosas de cada frase de vuelta al español (sin ver la frase) y Titan compara su significado con la original.

**Es una lista para priorizar, no un veredicto.** En la primera medición, de las 15 frases más bajas solo unas 3 tenían un problema real (p. ej. «Me la robaron.» → ROBAR · CELULAR): muchas vueltas salen escritas como glosas y bajan frases correctas, y una palabra añadida puede no bajar el parecido.

**376 frases revisadas · mediana 0.72 · 91 por debajo de 0.60.**

| Similitud | Frase | Glosas | Vuelta al español |
|---:|---|---|---|
| 0.12 | Necesito llamar. | LLAMAR | Llamar |
| 0.30 | Fue robo. | ROBAR | Robar |
| 0.31 | ¿Cuánto cuesta la cédula física? | CUANTOS · COSTO · PAPEL · IDENTIDAD · FISICA | ¿Cuántos cuesta el papel de identidad física? |
| 0.34 | Mi carnet necesita renovación. | PAPEL · IDENTIDAD · NUEVO · NECESITAR | PAPEL IDENTIDAD NUEVO NECESITAR |
| 0.34 | Incluya qué pasó, cuándo y dónde, si lo sabe. | PASADO · DONDE · CUANDO · SABER · YO | En el pasado, ¿dónde y cuándo sé yo? |
| 0.35 | No sé si cambió. | NO SABER · CAMBIAR | No saber cambiar |
| 0.36 | ¿Debo pagar por el nuevo carnet? | NUEVO · PAPEL · IDENTIDAD · PAGAR · DEBO | NUEVO PAPEL IDENTIDAD PAGAR DEBO |
| 0.39 | Perdí mi cédula. Necesito otra. | YO · PAPEL · IDENTIDAD · PERDER · NUEVO · NECESITAR | Yo papel de identidad perder nuevo necesitar |
| 0.42 | No fue robo. | ROBAR · NO | Robar no |
| 0.43 | ¿Su cédula ya venció? | TU · PAPEL · IDENTIDAD · VENCER · YA | ¿Tu papel de identidad vencer ya? |
| 0.43 | Me la robaron. | CELULAR · ROBAR | Robar celular |
| 0.43 | ¿Qué horario tiene? | HORA · TENER · CUAL | ¿Cuál hora tener? |
| 0.43 | Sí, aquí está mi cédula. | SI · AQUI · ESTAR · YO · PAPEL · IDENTIDAD | ¿Si yo estoy aquí con papel de identidad? |
| 0.43 | Sí. Los tengo en este documento. | SI · ESTE · PAPEL · TENER | ¿Si este papel tener? |
| 0.44 | La reposición mantiene la vigencia del documento reemplazado. | PAPEL · REEMPLAZAR · VIGENCIA · MANTENER | Reemplazar papel de vigencia mantener |
| 0.44 | No, pertenece a otra persona. | NO · OTRO · PERSONA | No otra persona |
| 0.44 | Sí, lo traje. | YO · TRAER | Yo traer |
| 0.44 | Necesito buscar. | BUSCAR | Buscar |
| 0.44 | No está vencido. | NO · VENCER | No vencer |
| 0.44 | Soy su hijo y tengo mi cédula. | YO · HIJO · TENER · PAPEL · IDENTIDAD | Yo tengo un hijo con papel de identidad |
| 0.45 | Confirmaré mi caso antes de ir. | CASO · CONFIRMAR · IR | CASO CONFIRMAR IR |
| 0.45 | No entiendo. | NO · COMPRENDER | No comprender |
| 0.45 | ¿Cuándo y dónde ocurrió el robo? | ROBAR · CUANDO · DONDE | Robar cuando dónde |
| 0.45 | Entiendo. Iré al servicio para víctimas. | ENTENDER · SERVICIO · VICTIMA · IR | Entender el servicio de víctima ir |
| 0.46 | ¿Tiene su cédula de identidad? | TU · PAPEL · IDENTIDAD · TENER | Tú tener papel de identidad |
| 0.46 | Escríbala sin espacios ni guiones. | ESCRIBIR | Escribir |
| 0.46 | Está vencido. | VENCER | Vencer |
| 0.47 | La renovación puede solicitarse desde seis meses antes. | MESES · 6 · ANTES · SOLICITAR · PODER | ¿Meses seis antes solicitar poder? |
| 0.47 | No la traje. | TRAE · NO | Trae no |
| 0.47 | Mi expareja me amenaza todos los días. | DIA · PAREJA · AMENAZAR · MUCHO | Día pareja amenazar mucho |
| 0.47 | ¿Debo volver a calificarme? | VOLVER · CALIFICAR · DEBO | VOLVER CALIFICAR DEBO |
| 0.47 | No recuerdo. | RECORDAR · NO SABER | Recordar no saber |
| 0.47 | El Ministerio informa que la carnetización es gratuita. | MINISTERIO · INFORMAR · PAPEL · IDENTIDAD · GRATIS | Ministerio informar papel identidad gratis |
| 0.49 | Registraremos su necesidad de interpretación. | NECESITAR · INTERPRETE | Necesitar intérprete |
| 0.49 | No entiendo bien explicaciones solo habladas. | ENTENDER · BIEN · EXPLICACION · HABLAR · SOLO | Entiendo bien la explicación que habla solo |
| 0.49 | No sé cuáles son. | NO SABER · CUAL · SER | No saber cuál ser |
| 0.49 | No sé dónde está. | NO SABER · DONDE · ESTAR | ¿No sabes dónde estar? |
| 0.49 | Necesito sacar mi cédula por primera vez. | PRIMERA VEZ · PAPEL · IDENTIDAD · SACAR | La primera vez sacar papel de identidad |
| 0.50 | No recuerdo el grado de mi carnet. | RECORDAR · NO · PAPEL · IDENTIDAD · GRADO | Recordar no papel identidad grado |
| 0.50 | Iré por la mañana. | MAÑANA · IR | Mañana ir |
| 0.50 | Solo legal. | LEGAL | Legal |
| 0.50 | Sí, lo tengo. | YO · TENER | Yo tener |
| 0.51 | No lo traje. | TRABAJADOR · TRAER · NO | Trabajador traer no |
| 0.51 | Quiero hacerlo hoy. | HOY · HACER · QUERER | Hoy hacer querer |
| 0.51 | Fue robo. Me quitaron el celular. | ROBAR · CELULAR · QUITAR | Quitar robar celular |
| 0.51 | No sé si están vigentes. | NO SABER · ESTAR · VIGENTE | No saber estar vigente |
| 0.52 | Compré un auto. Quiero pasarlo a mi nombre. | COMPRAR · MÍO · NOMBRE · PASAR | Comprar mío nombre pasar |
| 0.52 | No responderé cosas que no comprendo. | NO SABER · COSAS · RESPONDER | No saber cosas responder |
| 0.52 | Ya tengo una. | YO · TENER | Yo tener |
| 0.52 | ¿Pueden indicarme cómo contactarla? | YO · CONTACTAR · ELLA · COMO | Yo contactar ella cómo |
| 0.53 | Quiero revisar todo antes de pagar. | TODO · REVISAR · PAGAR · NO PUEDO | Todo revisar pagar no puedo |
| 0.53 | Queda entre Antezana y Lanza, Edificio Aly. | ANTERIOR · LANZA EDIFICIO ALY | Anterior lanza edificio Aly |
| 0.53 | La reposición aplica por extravío, robo o deterioro. | EXTRAVIO · ROBAR · DETIEN · APLICAR | ¿Extravío robar detien aplicar? |
| 0.53 | No lo tengo. | NO · TENER | No tener |
| 0.53 | No. Quiero encontrar una cerca. | NO · BUSCAR · CERCA | No buscar cerca |
| 0.54 | ¿Tiene NUREJ y WebID? | NUREJWEBID | Nurejwibid |
| 0.54 | También años anteriores. | AÑO · PASADO | Año pasado |
| 0.54 | No asumiremos que el servicio dejó de funcionar. | SERVICIO · FUNCIONAR · DEJAR · NO | No dejar que el servicio funcione |
| 0.54 | No sé. | NO SABER | No saber |
| 0.54 | Sí. Estoy lejos de esa persona. | LEJOS · PERSONA · ESTAR | Lejos persona estar |
| 0.54 | El arancel publicado incluye anticréticos entre otras escrituras. | PUBLICAR · ARANCELE · INCLUIR · OTRO · ESCRITURA | Publicar arancele incluir otro escritura |
| 0.55 | No sé el trámite. | NO SABER · TRAMITE | No saber tramite |
| 0.55 | Necesito ambas. No sé qué hacer. | NECESITAR · AMBOS · NO SABER · HACER | Necesitar ambos no saber hacer |
| 0.55 | También enumera identificación del fallecido y dos testigos. | IDENTIFICAR · FALLECIDO · TESTIGO · TESTIGO | Identificar fallecido testigo testigo |
| 0.55 | Sí. Necesito saber qué documentos llevar. | SI · NECESITAR · SABER · PAPEL · LLEVAR | Si necesitar saber papel llevar |
| 0.56 | Sí. | SI | Si |
| 0.56 | Tengo cédula y Folio, pero no formulario. | YO · PAPEL · IDENTIDAD · FOLIO · NO · FORMULARIO | Yo papel identidad folio no formulario |
| 0.56 | No sé si llegaré. | NO SABER · LLEGAR | No saber llegar |
| 0.56 | No borre ni modifique mensajes relacionados al hecho. | NO · BORRAR · MODIFICAR · MENSAJE · HECHO | No borrar, modificar el mensaje hecho |
| 0.56 | ¿Puede venir a la oficina de la Defensoría? | OFICINA · DEFENSORIA · VENIR · PODER | Oficina defensoría venir poder |
| 0.56 | Fue por internet. Envié dinero. | INTERNET · BILLETES · ENVIAR | Enviar billetes por internet |
| 0.56 | Sí, está a mi nombre. | YO · NOMBRE | Yo nombre |
| 0.57 | No sé qué memorial. | NO SABER · MEMORIAL | No saber memorial |
| 0.57 | Falta más tiempo. | TIEMPO · MAS | Tiempo mas |
| 0.58 | Describa cuándo y dónde ocurrió. | CUANDO · DONDE · OCURRIR | ¿Cuándo y dónde ocurrió? |
| 0.58 | Estaba cerrada. | CERRADO | Está cerrado |
| 0.58 | ¿Las amenazas continúan actualmente? | AHORA · AMENAZAR · CONTINUAR | Ahora amenazar continuar |
| 0.58 | No recuerdo esos números. | RECORDAR · NO · NUMERO | ¿Recuerdas el número? |
| 0.58 | Quiero saber qué pasó con mi denuncia. | YO · DENUNCIA · PASAR · QUE · SABER | Yo denuncio que paso, ¿qué sé? |
| 0.58 | Sí tengo. | SI · TENER | ¿Si tienes? |
| 0.58 | No debo años anteriores. | AÑO · PASADO · NO · DEBO | Año pasado no debo |
| 0.58 | DIRNOPLU ofrece un buscador de notarios. | DIRNOPLU · BUSCAR · NOTARIO | Dirigirse al notario para buscar |
| 0.59 | No sé qué incluye. | NO SABER · INCLUIR · QUE | No saber incluir que |
| 0.59 | No sé si sigue representándome. | NO SABER · REPRESENTAR · YO | Yo no sé representar |
| 0.59 | Sí. Ya firmamos la compra. | SI · COMPRAR · FIRMAR | ¿Si comprar firmar? |
| 0.59 | No tengo. | NO · TENER | No tener |
| 0.59 | ¿Qué trámite viene a registrar? | TRAMITE · REGISTRAR · VENIR | Trámite registrar venir |
| 0.59 | Necesito comunicarme en Lengua de Señas Boliviana. | YO · NECESITAR · COMUNICAR · LSB | Yo necesito comunicar LSB |
| 0.60 | Tengo los mensajes guardados. | TENER · MENSAJE · GUARDAR | Tener mensaje guardar |
| 0.60 | Quiero sacar mi carnet de discapacidad. | YO · QUERER · PAPEL · IDENTIDAD · DISCAPACIDAD · SACAR | Yo querer papel identidad discapacidad sacar |
| 0.60 | Se informó condonación de multas e intereses hasta octubre. | INFORMAR · MULTA · INTERES · OCTUBRE · HASTA | Informar multa interés octubre hasta |
