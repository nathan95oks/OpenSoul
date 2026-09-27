# Revisión de glosas del corpus RAG

Generado por `tool/rag_revisar_glosas.py`. No editar a mano.

Para cada frase, Bedrock dice qué palabras no tienen glosa y qué glosas no están en la frase, y traduce las glosas de vuelta al español sin ver la frase; Titan compara el significado de esa vuelta con la original (el parecido ordena la lista; no marca por sí solo). Se descarta lo que no es un error comprobable: palabras que LSB no signa (artículos, preposiciones, «ser/estar»), verbos conjugados de una glosa, sujetos que el español calla (YO) y lo que la frase sí dice (SI/«Sí», números). Una marca pide revisar, no corrige nada.

**376 frases revisadas · 6 para revisar · 44 menores · parecido mediano 0.82 · 14 vueltas no eran español y no se compararon.**

## Para revisar

Falta o sobra una palabra con significado. Dentro de cada grupo, primero las que más marcas tienen y el parecido más bajo.

| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |
|---|---|---:|---|---|---|
| cómo | — | 0.51 | No sé cómo solicitarlo. | NO SABER · SOLICITAR · EL | No sé solicitar eso. |
| pertenece | — | 0.54 | No, pertenece a otra persona. | NO · OTRO · PERSONA | No es otra persona |
| — | ADE CUADA | 0.73 | Gracias. Esperaré la asistencia adecuada. | GRACIAS · ESPERAR · ASISTENCIA · ADE CUADA | Gracias por la asistencia esperada adecuada |
| — | AÚN | 0.76 | ¿Todavía hay descuento si pago hoy? | HOY · PAGAR · DESCUENTO · AÚN · TODAVÍA | Hoy aún tengo que pagar con descuento |
| entiendo | — | 0.83 | No entiendo. | NO · COMPRENDER | No comprendo |
| ninguna | — | 0.89 | No. No tengo ninguna carátula. | NO · TENER · CARATULA | No tengo carátula |

## Menores

Solo falta un verbo auxiliar o de modo («quiero», «debe», «tengo»): la idea llega, el matiz no.

| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |
|---|---|---:|---|---|---|
| Necesito | — | 0.19 | Necesito buscar. | BUSCAR | Busco |
| Quiero | — | 0.38 | No. Quiero encontrar una cerca. | NO · BUSCAR · CERCA | No busqué cerca |
| Necesito | — | 0.62 | Necesito llamar. | LLAMAR | Voy a llamar |
| Quiero | — | 0.62 | Quiero saber dónde iniciar en Cochabamba. | COCHABAMBA · INICIAR · DONDE | ¿Dónde inicia Cochabamba? |
| Quiero | — | 0.64 | Quiero continuar con el trámite. | CONTINUAR · TRAMITE | Continuar el trámite |
| Quiero | — | 0.66 | Quiero saber qué pasó con mi denuncia. | YO · DENUNCIA · PASAR · QUE · SABER | Yo quiero pasar la denuncia, ¿qué sé? |
| Quiero | — | 0.66 | Sí. Quiero ir hoy. | SI · HOY · IR | Sí, hoy iré |
| Quiero | — | 0.67 | Quiero solicitar ese certificado. | SOLICITAR · CERTIFICADO | Solicito certificado |
| Quiero | — | 0.67 | Sí. Quiero ir personalmente. | YO · IR · PERSONALMENTE | Yo voy personalmente |
| Quiero | — | 0.68 | Quiero hacerlo verbalmente. | YO · HACER · VERBALMENTE | Yo hice verbalmente |
| Necesito | — | 0.68 | Necesito sacar mi cédula por primera vez. | PRIMERA VEZ · PAPEL · IDENTIDAD · SACAR | Sacó mi cédula de identidad por primera vez |
| Queremos | — | 0.69 | Sí. Queremos reconocer nuestras firmas. | SI · RECOCNER · NUESTRAS · FIRMA | Sí, reconozco que necesitamos firmar nuestras firmas |
| Puede | — | 0.70 | Puede buscarlos en una boleta de pago anterior. | BOLETA · PAGO · ANTERIOR · BUSCAR | Busque la boleta de pago anterior |
| tiene | — | 0.73 | La certificación de firmas tiene arancel publicado específico. | CERTIFICADO · FIRMA · ARANCELE · PUBLICADO · ESPECIFICO | ¿Usted tiene certificado de firma arancelario publicado específico? |
| Quiero | — | 0.74 | Quiero iniciar la atención. | INICIAR · ATENCION | Empecé la atención |
| Quiero | — | 0.75 | Quiero solicitarlo ahora. | AHORA · SOLICITAR | Ahora solicito |
| debe | — | 0.75 | La atención debe permitir comunicación accesible. | ATENCION · COMUNICACION · ACCESIBLE · PERMITIR | Permito atención de comunicación accesible |
| debe | — | 0.76 | Primero debe seguir el proceso de calificación correspondiente. | PROCESO · CALIFICACION · CORRESPONDIENTE · PRIMERO | Primero la calificación del proceso corresponde |
| Quiero | — | 0.76 | Quiero que me indiquen dónde acudir. | INDICAR · DONDE · ACUDIR | Indique dónde acudir |
| Quiero | — | 0.77 | Compré una casa. Quiero ponerla a mi nombre. | COMPRAR · CASA · YO · NOMBRE · PONER | Puse mi nombre al comprar la casa |
| Quiero | — | 0.78 | Quiero hacer un documento de anticrético. | YO · HACER · PAPEL · ANTICRETICO | Yo hice el documento anticrético |
| Tengo | — | 0.78 | Tengo cédula y Folio, pero no formulario. | YO · PAPEL · IDENTIDAD · FOLIO · NO · FORMULARIO | No tengo formulario para el folio de mi cédula de identidad |
| Debe | — | 0.79 | Debe garantizarse comunicación accesible durante la atención. | ATENCION · COMUNICACION · ACCESIBLE · GARANTIZAR · DURANTE | Garantizar atención de comunicación accesible durante |
| Quiero | — | 0.81 | Quiero recibir instrucciones claras por escrito también. | YO · INSTRUCCION · CLARO · ESCRIBIR · TAMBIEN · RECIBIR | Yo necesito escribir una instrucción clara y también recibirla |
| Debe | — | 0.82 | Debe ser derivado al servicio especializado contra la violencia. | VIOLENCIA · SERVICIO · ESPECIALIZADO · CONTRA · VIOLENCIA · DERIVADO | Derivó a un servicio especializado contra la violencia. |
| Tiene | — | 0.83 | ¿Tiene certificado de nacimiento original computarizado? | CERTIFICADO · NACIMIENTO · ORIGINAL · COMPUTADORA | El certificado de nacimiento original está en la computadora |
| Quiero | — | 0.84 | Quiero hablar con el equipo. | YO · EQUIPO · HABLAR | Yo puedo hablar con el equipo |
| Quiero | — | 0.84 | Quiero recibir orientación hoy. | HOY · ORIENTAR · RECIBIR | Hoy recibiré orientación |
| Quiero | — | 0.85 | Quiero certificar las firmas de este contrato. | YO · CONTRATO · FIRMA · CERTIFICAR | Yo necesito certificar la firma del contrato |
| Debe | — | 0.85 | Debe acreditar la relación permitida y su identidad. | RELACION · PERMITIDO · IDENTIDAD · ACREDITAR | La relación está permitida para acreditar la identidad |
| Quiero | — | 0.86 | Quiero saber cómo está mi proceso. | SABER · CÓMO · ESTAR · MÍO · PROCESO | Sé cómo está mi proceso |
| Quiero | — | 0.86 | Quiero denunciar el robo de mi celular. | YO · DENUNCIAR · ROBAR · CELULAR · MIO | Yo denuncié que me robaron mi celular |
| puede | — | 0.86 | El equipo puede orientar su ruta de atención. | EQUIPO · ATENCION · RUTA · ORIENTAR | El equipo de atención puede orientar el camino |
| Quiero | — | 0.86 | Quiero denunciar violencia de mi pareja. | YO · DENUNCIAR · VIOLENCIA · PAREJA · MÍO | Yo denuncé la violencia de mi pareja. |
| Debe | — | 0.87 | Debe activarse la atención de la Defensoría de la Niñez. | ATENCION · DEFENSORIA · NIÑEZ · ACTIVAR | ¿Activan la atención de la Defensoría de la Niñez? |
| Quiero | — | 0.87 | Quiero saber si mi casa tiene hipoteca. | YO · CASA · HIPOTECA · TENER · SABER | Yo quiero saber si tengo la hipoteca de la casa |
| Quiero | — | 0.88 | Quiero confirmar el costo total primero. | YO · COSTO · TOTAL · CONFIRMAR · PRIMERO | Confirmo primero el costo total |
| Puede | — | 0.89 | Puede acudir a la Defensoría por posible vulneración de derechos. | POSIBLE · DERECHOS · VULNERACION · DEFENSORIA · ACUDIR | Es posible acudir a la Defensoría para la vulneración de derechos |
| Tengo | — | 0.89 | Tengo audiencia familiar. No sé dónde ir. | AUDIENCIA · FAMILIAR · NO SABER · DONDE · IR | No sé a dónde ir a la audiencia familiar |
| debe | — | 0.91 | La atención debe adaptarse para que comprenda el trámite. | ATENCION · ADAPTARSE · COMPRENDER · TRAMITE · PARA QUE | La atención se adapta para comprender el trámite |
| Quiero | — | 0.92 | Quiero saber dónde puedo informar el caso. | CASO · INFORMAR · DONDE · PUEDO | Yo necesito informar el caso, ¿dónde puedo? |
| Necesito | — | 0.97 | Necesito ayuda por violencia de mi pareja. | AYUDA · VIOLENCIA · PAREJA · MÍO | Necesito ayuda por la violencia de mi pareja |
| Necesito | — | 0.99 | Necesito ayuda legal y psicológica. | AYUDA · LEGAL · PSICOLOGICA | Necesito ayuda legal y psicológica |
| quiere | — | — | ¿Qué hecho quiere denunciar? | DENUNCIAR · HECHO · QUE | ¿Qué hecho denunciar? |
