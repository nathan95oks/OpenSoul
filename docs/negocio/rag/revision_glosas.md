# Revisión de glosas del corpus RAG

Generado por `tool/rag_revisar_glosas.py`. No editar a mano.

Para cada frase, Bedrock dice qué palabras no tienen glosa y qué glosas no están en la frase, y traduce las glosas de vuelta al español sin ver la frase; Titan compara el significado de esa vuelta con la original (el parecido ordena la lista; no marca por sí solo). Se descarta lo que no es un error comprobable: palabras que LSB no signa (artículos, preposiciones, «ser/estar»), verbos conjugados de una glosa, sujetos que el español calla (YO) y lo que la frase sí dice (SI/«Sí», números). Una marca pide revisar, no corrige nada.

**376 frases revisadas · 90 para revisar · 56 menores · parecido mediano 0.80 · 13 vueltas no eran español y no se compararon.**

## Para revisar

Falta o sobra una palabra con significado. Dentro de cada grupo, primero las que más marcas tienen y el parecido más bajo.

| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |
|---|---|---:|---|---|---|
| Vine, contra, adolescente | ADULTO | 0.68 | Vine por violencia contra mi sobrino adolescente. | VIOLENCIA · SOBRINO · ADULTO · YO · VENIR | Violencia de sobrino adulto, yo vengo |
| Quiero, antes | NO PUEDO | 0.48 | Quiero revisar todo antes de pagar. | TODO · REVISAR · PAGAR · NO PUEDO | Reviso todo, no puedo pagar |
| todos | DIA, MUCHO | 0.60 | Mi expareja me amenaza todos los días. | DIA · PAREJA · AMENAZAR · MUCHO | Mi pareja me amenazó mucho hoy |
| Registraremos, usted, pueda | — | 0.66 | Registraremos los datos que usted pueda aportar. | DATOS · APORTAR · PODER | Puede aportar datos |
| anticréticos, otras | — | 0.30 | El arancel publicado incluye anticréticos entre otras escrituras. | PUBLICAR · ARANCELE · INCLUIR · OTRO · ESCRITURA | Incluir otro escrito en la tarifa pública |
| espacios, guiones | — | 0.43 | Escríbala sin espacios ni guiones. | ESCRIBIR | Escriba |
| hacerle, algunas | — | 0.45 | Necesito hacerle algunas preguntas sobre la denuncia. | PREGUNTAR · DENUNCIA · NECESITAR | ¿Necesita denunciar? |
| auto, Quiero | — | 0.57 | Compré un auto. Quiero pasarlo a mi nombre. | COMPRAR · MÍO · NOMBRE · PASAR | Mi nombre pasará a comprar |
| traje | TRAE | 0.59 | No la traje. | TRAE · NO | No lo traigo |
| Quiero, directamente | — | 0.60 | Quiero participar directamente en mi audiencia. | YO · AUDIENCIA · PARTICIPAR | Participaré en la audiencia |
| Pueden, indicarme | — | 0.61 | ¿Pueden indicarme cómo contactarla? | YO · CONTACTAR · ELLA · COMO | Yo contactar a ella, ¿cómo? |
| Contacte, correspondiente | — | 0.67 | Contacte SEPDEP para activar la atención correspondiente. | SEPDEP · ATENDER · ACTIVAR | Vamos a activar para atender a SEPDEP |
| atiende, correspondiente | — | 0.68 | FELCV atiende hechos de violencia y activa la ruta correspondiente. | FELCV · VIOLENCIA · HECHO · ATENDER · RUTA · ACTIVAR | Activen la ruta para atender el hecho de violencia felina |
| Consulte | AHORA | 0.71 | Consulte primero el monto actualizado antes de pagar. | AHORA · MONTO · ACTUALIZAR · PAGAR · ANTES | Ahora debe pagar el monto actualizado |
| SERECI, servicio | — | 0.73 | SERECI incluye ese servicio entre certificados duplicados. | CERTIFICADO · DUPLICADO · INCLUIR | El certificado duplicado incluye |
| renovación, puede | — | 0.73 | La renovación puede solicitarse desde seis meses antes. | MESES · 6 · ANTES · SOLICITAR · PODER | Puede solicitarlo 6 meses antes |
| Debe, conforme | — | 0.74 | Debe tramitarse la interpretación conforme al procedimiento aplicable. | TRAMITE · INTERPRETAR · PROCEDIMIENTO · APLICABLE | Necesito interpretar el procedimiento aplicable para el trámite. |
| Primero, debe | — | 0.75 | Primero debe seguir el proceso de calificación correspondiente. | PROCESO · CALIFICACION · CORRESPONDIENTE | El proceso de calificación corresponde |
| Primero | AHORA | 0.75 | Primero confirmaré la sede y horario. | AHORA · SEDE · HORA · CONFIRMAR | Ahora confirmar la hora de la sede |
| Quiero | PRIMERA VEZ | 0.76 | Quiero confirmar el costo total primero. | YO · COSTO · TOTAL · PRIMERA VEZ · CONFIRMAR | Yo confirmo el costo total por primera vez |
| Tengo | CASO | 0.77 | Tengo deuda antigua de mi casa. | CASO · ANTIGUO · DEUDA · MÍO · CASA | En mi caso antiguo la deuda es de la casa |
| Quiero, quede | — | 0.82 | Quiero que quede registrada mi solicitud. | YO · SOLICITUD · REGISTRAR | Yo necesito registrar la solicitud. |
| otra | NUEVO | 0.83 | Perdí mi cédula. Necesito otra. | YO · PAPEL · IDENTIDAD · PERDER · NUEVO · NECESITAR | Necesito una nueva cédula de identidad porque la perdí |
| quiero | AHORA | 0.88 | Entonces quiero confirmar el precio primero. | AHORA · PRECIO · CONFIRMAR · PRIMERO | Primero debo confirmar el precio ahora. |
| actualmente | AHORA | 0.92 | ¿Tiene actualmente abogado particular? | AHORA · ABOGADO · PARTICULAR · TENER | ¿Ahora tiene abogado particular? |
| Queda | — | 0.38 | Queda entre Antezana y Lanza, Edificio Aly. | ANTERIOR · LANZA EDIFICIO ALY | El edificio anterior lanza alianzas |
| ofrece | — | 0.47 | DIRNOPLU ofrece un buscador de notarios. | DIRNOPLU · BUSCAR · NOTARIO | Busque al director o al jefe de nómina |
| asumiremos | — | 0.47 | No asumiremos que el servicio dejó de funcionar. | SERVICIO · FUNCIONAR · DEJAR · NO | ¿No deja de funcionar el servicio? |
| Registraremos | — | 0.48 | Registraremos su necesidad de interpretación. | NECESITAR · INTERPRETE | ¿Necesita intérprete? |
| No | — | 0.48 | No entiendo bien explicaciones solo habladas. | ENTENDER · BIEN · EXPLICACION · HABLAR · SOLO | Entiendo bien la explicación, hable solo |
| Usaré | — | 0.49 | Usaré el buscador oficial. | BUSCAR · OFICIAL | Busco al oficial |
| cómo | — | 0.51 | No sé cómo solicitarlo. | NO SABER · SOLICITAR · EL | No sé solicitar eso. |
| — | NO SABER | 0.51 | No responderé cosas que no comprendo. | NO SABER · COSAS · RESPONDER | No sé las cosas para responder |
| — | CELULAR | 0.54 | Me la robaron. | CELULAR · ROBAR | Me robaron el celular |
| pertenece | — | 0.54 | No, pertenece a otra persona. | NO · OTRO · PERSONA | No es otra persona |
| adecuada | — | 0.55 | Gracias. Esperaré la asistencia adecuada. | GRACIAS · ESPERAR · ASISTENCIA | Gracias por la asistencia a la espera |
| enumera | — | 0.55 | También enumera identificación del fallecido y dos testigos. | IDENTIFICAR · FALLECIDO · TESTIGO · TESTIGO | ¿Puede identificar al fallecido, testigo? |
| — | AHORA | 0.56 | ¿Las amenazas continúan actualmente? | AHORA · AMENAZAR · CONTINUAR | Ahora continúe, lo estoy amenazando |
| — | TRABAJADOR | 0.56 | No lo traje. | TRABAJADOR · TRAER · NO | El trabajador no trae |
| Describa | — | 0.58 | Describa cuándo y dónde ocurrió. | CUANDO · DONDE · OCURRIR | ¿Cuándo y dónde ocurrió? |
| toda | — | 0.58 | No puedo pagar toda la deuda del auto. | DEUDA · PAGAR · NO PUEDO · TODO | No puedo pagar la deuda, todo |
| — | DETIEN | 0.58 | La reposición aplica por extravío, robo o deterioro. | EXTRAVIO · ROBAR · DETIEN · APLICAR | Si hay extravío o robo, deben aplicar el detenimiento |
| Incluya | — | 0.59 | Incluya qué pasó, cuándo y dónde, si lo sabe. | PASADO · DONDE · CUANDO · SABER · YO | Yo sé dónde y cuándo fue lo pasado |
| antes | — | 0.60 | Confirmaré antes de pagar. | PAGAR · CONFIRMAR | Confirmo que he pagado |
| citaron | — | 0.62 | Sí. Me citaron y no tengo abogado. | YO · LLAMAR · NO · ABOGADO · TENER | No necesito llamar a un abogado |
| ocurrió | — | 0.64 | ¿Cuándo y dónde ocurrió el robo? | ROBAR · CUANDO · DONDE | ¿Cuándo y dónde robaron? |
| condonación | — | 0.64 | Se informó condonación de multas e intereses hasta octubre. | INFORMAR · MULTA · INTERES · OCTUBRE · HASTA | Informar de la multa de interés hasta octubre |
| — | SI | 0.66 | ¿Sigue funcionando allí? | ALLI · FUNCIONAR · SI | Sí, funciona allí |
| — | NO | 0.66 | ¿Puede ingresar a su cuenta? | CUENTA · INGRESAR · PUEDO · NO | No puedo ingresar la cuenta |
| Solo | — | 0.66 | Solo legal. | LEGAL | Es legal |
| esos | — | 0.67 | No recuerdo esos números. | RECORDAR · NO · NUMERO | No recuerdo el número |
| — | NO SABER | 0.67 | No recuerdo. | RECORDAR · NO SABER | No sé recordarlo |
| — | BILLETES | 0.69 | Sí tengo mi última boleta. | ULTIMO · BILLETES · TENER · YO | Yo tengo los últimos billetes |
| — | YES | 0.69 | ¿Le dijeron que necesita treinta por ciento? | NEED · THIRTY · PERCENT · YES | Necesito el 30% |
| sigo | — | 0.70 | ¿Entonces aquí no sigo el trámite? | AQUI · TRAMITE · SIGUIR · NO | Aquí no se sigue el trámite |
| Entiendo | — | 0.70 | Entiendo. Iré al servicio para víctimas. | ENTENDER · SERVICIO · VICTIMA · IR | Entiendo que el servicio para víctima va |
| Primero | — | 0.72 | Primero confirmaré la sede. | CONFIRMAR · SEDE | Confirmo la sede |
| relacionados | — | 0.72 | No borre ni modifique mensajes relacionados al hecho. | NO · BORRAR · MODIFICAR · MENSAJE · HECHO | No borre ni modifique el mensaje hecho |
| figura | — | 0.72 | El servicio para violencia familiar figura actualizado en 2026. | VIOLENCIA · FAMILIAR · SERVICIO · ACTUALIZAR · 2 · 0 · 2 · 6 | ¿Actualiza el servicio de violencia familiar el 20 de febrero? |
| Primero | — | 0.73 | Primero confirmaré el monto. | CONFIRMAR · MONTO | Confirmo el monto |
| — | TENER | 0.73 | Sí. La dirección que tenía estaba cerrada. | DIRECCION · TENER · CERRADO | La dirección está cerrada |
| Depende | — | 0.74 | Depende de su grado y situación; revise la norma aplicable. | GRADO · SITUACION · NORMA · APLICABLE · REVISAR | Revisaré el grado de situación según la norma aplicable |
| exacto | — | 0.74 | Entonces confirmaré el trámite exacto. | TRAMITE · CONFIRMAR | Confirmo el trámite |
| dice | — | 0.75 | ¿Cuánto dice la página que cuesta? | CUANTOS · PAGINA · COSTO | ¿Cuántas páginas cuestan? |
| Todavía | — | 0.77 | ¿Todavía hay descuento si pago hoy? | HOY · PAGAR · DESCUENTO · AUN | Aún hoy puedo pagar con descuento |
| — | INTERNET | 0.77 | Haré la consulta en línea. | HACER · CONSULTA · INTERNET | Hice la consulta por internet |
| solamente | — | 0.78 | ¿Su deuda corresponde solamente a 2025? | DEUDA · CORRESPONDER · SOLO · 2 · 0 · 2 · 5 | La deuda corresponde solo al 2025 |
| corresponde | — | 0.81 | Para violencia corresponde activar la ruta de FELCV. | VIOLENCIA · FELCV · RUTA · ACTIVAR | Se activa la ruta del FELCV por violencia |
| indica | — | 0.81 | SIREJ indica acudir a información del Tribunal. | SIREJ · TRIBUNAL · INFORMACION · ACUDIR | Al Tribunal Sirej hay que acudir para información |
| — | LO | 0.81 | No sé cómo hacerlo. | NO SABER · COMO · HACER · LO · YO | No sé cómo hacer esto yo |
| viene | — | 0.83 | ¿Qué trámite viene a registrar? | TRAMITE · REGISTRAR · VENIR | Venga a registrar el trámite |
| entiendo | — | 0.83 | No entiendo. | NO · COMPRENDER | No comprendo |
| Existe | — | 0.84 | Existe representación en Centro Integral FELCV, avenida Beijing. | CENTRO INTEGRAL FELCV · AVENIDA · BEIJING | El Centro Integral FELCV está en la Avenida Beijing |
| contempla | — | 0.85 | La Ley 1658 contempla interpretación gratuita en justicia. | LEY · 1 · 6 · 5 · 8 · JUSTICIA · INTERPRETAR · GRATIS | La ley 1658 interpreta justicia gratis |
| dentro | — | 0.86 | La norma 2025 mantiene el registro dentro del sistema nacional. | NORMA · 2 · 0 · 2 · 5 · REGISTRO · SISTEMA · NACIONAL · MANTENER | Mantiene la norma 2025 del Registro del Sistema Nacional |
| — | POR QUE | 0.87 | Necesito certificado porque robaron mis documentos. | CERTIFICADO · NECESITAR · PAPEL · ROBAR · POR QUE | Necesito el certificado porque me robaron el documento |
| — | QUIEN | 0.88 | ¿Qué ayuda necesita? | AYUDA · NECESITAR · QUIEN | ¿Quién necesita ayuda? |
| — | SI | 0.88 | ¿La dirección sigue vigente? | DIRECCION · VIGENTE · SI | La dirección está vigente, ¿sí? |
| incorporó | — | 0.88 | La norma 2025 incorporó mecanismos de renovación automática. | NORMA · 2 · 0 · 2 · 5 · MECANISMO · RENOVACION · AUTOMATICO | La norma 2025 tiene un mecanismo de renovación automática |
| ninguna | — | 0.89 | No. No tengo ninguna carátula. | NO · TENER · CARATULA | No tengo carátula |
| — | LA | 0.90 | Entonces ya puedo renovarla. | YA · PUEDO · RENOVAR · LA · ENTONCES | Ya puedo renovarla entonces |
| mismo | — | 0.92 | ¿Cuesta lo mismo que la cédula física? | CEDULA · FISICA · COSTO · IGUAL | La cédula física cuesta lo mismo |
| Fui | — | 0.93 | Fui víctima de robo. Necesito abogado gratuito. | YO · VICTIMA · ROBAR · NECESITAR · ABOGADO · GRATIS | Necesito un abogado gratis porque soy víctima de robo |
| — | CUAL | 0.93 | ¿Su deuda es de vehículo, inmueble o actividad? | VEHICULO · INMUEBLE · ACTIVIDAD · DEUDA · ES · CUAL | ¿Cuál es la deuda de vehículo, inmueble o actividad? |
| — | NO SABER | 0.94 | No sé dónde está. | NO SABER · DONDE · ESTAR | No sé dónde está |
| podré | — | 0.97 | No sé cuándo podré ir. | NO SABER · CUANDO · PODER · IR | No sé cuándo podré ir |
| — | QUERER | 0.98 | Quiero saber cómo está mi proceso. | QUERER · SABER · COMO ESTAS · MÍO · PROCESO | Quiero saber cómo está mi proceso |
| Cuente | — | 1.00 | Cuente lo ocurrido con sus propias palabras. | CONTAR · OCURRIDO · PROPIO · PALABRA | Cuente lo ocurrido con sus propias palabras. |
| Falta | — | — | Falta más tiempo. | TIEMPO · MAS | Más tiempo |
| muy | — | — | Sí, pero escribí muy poco. | SI · ESCRIBIR · POCO | Sí, escribir poco |

## Menores

Solo falta un verbo auxiliar o de modo («quiero», «debe», «tengo»): la idea llega, el matiz no.

| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |
|---|---|---:|---|---|---|
| Necesito | — | 0.19 | Necesito buscar. | BUSCAR | Busco |
| Quiero | — | 0.38 | No. Quiero encontrar una cerca. | NO · BUSCAR · CERCA | No busqué cerca |
| Debe | — | 0.49 | Debe acreditar la relación permitida y su identidad. | RELACION · PERMITIDO · IDENTIDAD · DEMOSTRAR | ¿Usted tiene permitido demostrar identidad? |
| tiene | — | 0.55 | ¿Qué horario tiene? | HORA · TENER · CUAL | ¿Cuál es su hora? |
| Tengo | — | 0.61 | Tengo los mensajes guardados. | TENER · MENSAJE · GUARDAR | Tengo que guardar el mensaje |
| Necesito | — | 0.62 | Necesito llamar. | LLAMAR | Voy a llamar |
| Quiero | — | 0.62 | Quiero saber dónde iniciar en Cochabamba. | COCHABAMBA · INICIAR · DONDE | ¿Dónde inicia Cochabamba? |
| Quiero | — | 0.64 | Quiero continuar con el trámite. | CONTINUAR · TRAMITE | Continuar el trámite |
| Quiero | — | 0.66 | Quiero saber qué pasó con mi denuncia. | YO · DENUNCIA · PASAR · QUE · SABER | Yo quiero pasar la denuncia, ¿qué sé? |
| Quiero | — | 0.66 | Quiero sacar mi carnet de discapacidad. | YO · QUERER · PAPEL · IDENTIDAD · DISCAPACIDAD · SACAR | Quiero sacar mi documento de identidad de discapacidad |
| Quiero | — | 0.66 | Sí. Quiero ir hoy. | SI · HOY · IR | Sí, hoy iré |
| Quiero | — | 0.67 | Quiero solicitar ese certificado. | SOLICITAR · CERTIFICADO | Solicito certificado |
| Quiero | — | 0.67 | Sí. Quiero ir personalmente. | YO · IR · PERSONALMENTE | Yo voy personalmente |
| Quiero | — | 0.68 | Quiero hacerlo verbalmente. | YO · HACER · VERBALMENTE | Yo hice verbalmente |
| Necesito | — | 0.68 | Necesito sacar mi cédula por primera vez. | PRIMERA VEZ · PAPEL · IDENTIDAD · SACAR | Sacó mi cédula de identidad por primera vez |
| Queremos | — | 0.69 | Sí. Queremos reconocer nuestras firmas. | SI · RECOCNER · NUESTRAS · FIRMA | Sí, reconozco que necesitamos firmar nuestras firmas |
| Puede | — | 0.70 | Puede buscarlos en una boleta de pago anterior. | BOLETA · PAGO · ANTERIOR · BUSCAR | Busque la boleta de pago anterior |
| Tengo | — | 0.73 | Tengo cédula, pero no traje CRPVA. | YO · PAPEL · IDENTIDAD · TENER · PERO · NO · TRAER · CRPVA | Perdí mi cédula de identidad, pero no traje el CRPVA |
| tiene | — | 0.73 | La certificación de firmas tiene arancel publicado específico. | CERTIFICADO · FIRMA · ARANCELE · PUBLICADO · ESPECIFICO | ¿Usted tiene certificado de firma arancelario publicado específico? |
| Quiero | — | 0.74 | Quiero iniciar la atención. | INICIAR · ATENCION | Empecé la atención |
| Quiero | — | 0.75 | Quiero solicitarlo ahora. | AHORA · SOLICITAR | Ahora solicito |
| debe | — | 0.75 | La atención debe permitir comunicación accesible. | ATENCION · COMUNICACION · ACCESIBLE · PERMITIR | Permito atención de comunicación accesible |
| Tengo | — | 0.75 | Sí. Tengo ambos códigos. | SI · TENER · AMBOS · CODIGO | Sí, ambos tenemos código |
| Quiero | — | 0.76 | Quiero que me indiquen dónde acudir. | INDICAR · DONDE · ACUDIR | Indique dónde acudir |
| Quiero | — | 0.77 | Compré una casa. Quiero ponerla a mi nombre. | COMPRAR · CASA · YO · NOMBRE · PONER | Puse mi nombre al comprar la casa |
| Quiero | — | 0.78 | Quiero hacer un documento de anticrético. | YO · HACER · PAPEL · ANTICRETICO | Yo hice el documento anticrético |
| Tengo | — | 0.78 | Tengo cédula y Folio, pero no formulario. | YO · PAPEL · IDENTIDAD · FOLIO · NO · FORMULARIO | No tengo formulario para el folio de mi cédula de identidad |
| Debe | — | 0.79 | Debe garantizarse comunicación accesible durante la atención. | ATENCION · COMUNICACION · ACCESIBLE · GARANTIZAR · DURANTE | Garantizar atención de comunicación accesible durante |
| Quiero | — | 0.81 | Quiero recibir instrucciones claras por escrito también. | YO · INSTRUCCION · CLARO · ESCRIBIR · TAMBIEN · RECIBIR | Yo necesito escribir una instrucción clara y también recibirla |
| tengo | — | 0.82 | No tengo memorial. Solo traje mi cédula. | YO · NO · TENER · MEMORIAL · SOLO · TRAER · MÍO · PAPEL · IDENTIDAD | No tengo el memorial, solo traigo mi cédula de identidad |
| Debe | — | 0.82 | Debe ser derivado al servicio especializado contra la violencia. | VIOLENCIA · SERVICIO · ESPECIALIZADO · CONTRA · VIOLENCIA · DERIVADO | Derivó a un servicio especializado contra la violencia. |
| Quiero | — | 0.82 | Quiero entender todas las preguntas de la denuncia. | YO · ENTENDER · PREGUNTA · DENUNCIA · TODOS | Entiendo todas las preguntas de la denuncia |
| Tiene | — | 0.83 | ¿Tiene certificado de nacimiento original computarizado? | CERTIFICADO · NACIMIENTO · ORIGINAL · COMPUTADORA | El certificado de nacimiento original está en la computadora |
| tengo | — | 0.84 | Me denunciaron y no tengo abogado. | YO · DENUNCIAR · NO · TENER · ABOGADO | No tengo abogado para denunciar |
| Quiero | — | 0.84 | Quiero hablar con el equipo. | YO · EQUIPO · HABLAR | Yo puedo hablar con el equipo |
| Quiero | — | 0.84 | Quiero recibir orientación hoy. | HOY · ORIENTAR · RECIBIR | Hoy recibiré orientación |
| Quiero | — | 0.85 | Quiero certificar las firmas de este contrato. | YO · CONTRATO · FIRMA · CERTIFICAR | Yo necesito certificar la firma del contrato |
| Quiero | — | 0.86 | Quiero denunciar el robo de mi celular. | YO · DENUNCIAR · ROBAR · CELULAR · MIO | Yo denuncié que me robaron mi celular |
| puede | — | 0.86 | El equipo puede orientar su ruta de atención. | EQUIPO · ATENCION · RUTA · ORIENTAR | El equipo de atención puede orientar el camino |
| Quiero | — | 0.86 | Quiero denunciar violencia de mi pareja. | YO · DENUNCIAR · VIOLENCIA · PAREJA · MÍO | Yo denuncé la violencia de mi pareja. |
| Debe | — | 0.87 | Debe activarse la atención de la Defensoría de la Niñez. | ATENCION · DEFENSORIA · NIÑEZ · ACTIVAR | ¿Activan la atención de la Defensoría de la Niñez? |
| Quiero | — | 0.87 | Quiero saber si mi casa tiene hipoteca. | YO · CASA · HIPOTECA · TENER · SABER | Yo quiero saber si tengo la hipoteca de la casa |
| Quiero | — | 0.88 | Quiero texto. | QUERER · TEXTO | Yo quiero texto |
| Puede | — | 0.89 | Puede acudir a la Defensoría por posible vulneración de derechos. | POSIBLE · DERECHOS · VULNERACION · DEFENSORIA · ACUDIR | Es posible acudir a la Defensoría para la vulneración de derechos |
| Tengo | — | 0.89 | Tengo audiencia familiar. No sé dónde ir. | AUDIENCIA · FAMILIAR · NO SABER · DONDE · IR | No sé a dónde ir a la audiencia familiar |
| debe | — | 0.91 | La atención debe adaptarse para que comprenda el trámite. | ATENCION · ADAPTARSE · COMPRENDER · TRAMITE · PARA QUE | La atención se adapta para comprender el trámite |
| Quiero | — | 0.92 | Quiero hacerlo hoy. | HOY · HACER · QUERER | Hoy quiero hacerlo |
| Quiero | — | 0.92 | Quiero saber dónde puedo informar el caso. | CASO · INFORMAR · DONDE · PUEDO | Yo necesito informar el caso, ¿dónde puedo? |
| tengo | — | 0.93 | No tengo CRPVA. | NO · TENER · CRPVA | No tengo CRPVA |
| Tengo | — | 0.95 | Tengo el certificado médico original. | CERTIFICADO · MEDICO · ORIGINAL · TENER | Tengo el certificado médico original |
| Quiero | — | 0.95 | Me robaron mi celular. Quiero denunciar. | CELULAR · ROBAR · DENUNCIAR · QUERER | Yo quiero denunciar que me robaron el celular |
| tengo | — | 0.96 | No tengo. | NO · TENER | No tengo |
| Necesito | — | 0.97 | Necesito ayuda por violencia de mi pareja. | AYUDA · VIOLENCIA · PAREJA · MÍO | Necesito ayuda por la violencia de mi pareja |
| Necesito | — | 0.99 | Necesito ayuda legal y psicológica. | AYUDA · LEGAL · PSICOLOGICA | Necesito ayuda legal y psicológica |
| tengo | — | 0.99 | Sí, tengo todo. | SI · TENER · TODO | Sí, tengo todo |
| quiere | — | — | ¿Qué hecho quiere denunciar? | DENUNCIAR · HECHO · QUE | ¿Qué hecho denunciar? |
