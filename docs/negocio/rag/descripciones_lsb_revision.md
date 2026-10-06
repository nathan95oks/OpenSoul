# Descripciones en LSB por revisar

Generado por `tool/build_rag_corpus.py`. No editar a mano.

La ventana «¿Qué es?» muestra la descripción en glosas LSB solo si la traducción provisional de la Lambda requiere revisión: cada seña se apoya en una palabra de la descripción, la negación coincide, las interrogativas solo van donde se pregunta, no se explica la palabra con ella misma y hay más señas que señas por incorporar. Estas no registran aquí, pero ya se ven en LSB en la aplicación. Para arreglarlas, reescribe la descripción en `descripciones_sin_sena.json` con palabras que tengan seña y vuelve a ejecutar `python tool/rag_descripciones_lsb.py` y `python tool/build_rag_corpus.py`.

**293 descripciones.** `*` = seña por incorporar.

| Palabra | Descripción | Traducción LSB | Motivo |
|---|---|---|---|
| ACCESO | Poder entrar a un lugar o ver una información. Ej.: ver su proceso en internet. | *ENTRAR · *LUGAR · VER · *INFORMACION · INTERNET · *PROCESO · VER | (sobre todo señas por incorporar) |
| ACTIVAR | Hacer que un servicio o trámite empiece a funcionar. | HACER · *SERVICIO · TRAMITE · EMPEZAR · FUNCIONAR | EMPEZAR |
| ACTUALIZADO | Con los datos de hoy, renovado. | HOY · *DATOS · *RENOVAR | (sobre todo señas por incorporar) |
| ACUSAR | Decir que una persona hizo algo malo. | *DECIR · *PERSONA · HACER · MALO | HACER |
| ADAPTARSE | Cambiar para que algo sirva a una persona. Ej.: la atención se adapta a la persona sorda. | CAMBIAR · *SIRVE · *PERSONA · PARA_QUE | PARA_QUE |
| ADE_CUADA | La que sirve bien para lo que se necesita. | *BIEN · *SERVIR · NECESITAR | (sobre todo señas por incorporar) |
| ADMINISTRACION | Organizar y dirigir algo. «Administración de justicia»: el trabajo de jueces y tribunales. | ORGANIZAR · *DIRIGIR · JUSTICIA · TRABAJADOR · JUEZ · *TRIBUNAL | JUEZ |
| ADQUIRIR | Conseguir algo para que sea suyo, por ejemplo comprando una casa. | *ALGO · TENER · SUYO · PARA_QUE | TENER, PARA_QUE |
| ADQUISICION | Cuando alguien consigue algo para que sea suyo. «Escritura de adquisición»: documento de la compra. | *ALGUIEN · *CONSIGUE · *ALGO · SUYO · PARA_QUE | (sobre todo señas por incorporar), PARA_QUE |
| AGREGAR | Poner algo más. | *PONER · *ALGO · *MAS | (sobre todo señas por incorporar), (ninguna seña) |
| ALCANCE | Hasta dónde llega o vale algo. Un certificado puede valer en un departamento o en todo el país. | DONDE · LLEGAR · *VALE · *ALGO · CERTIFICADO · *VALE · *DEPARTAMENTO · *PAIS · *TODO | (sobre todo señas por incorporar) |
| ALGO | Una cosa, sin decir cuál. | COSAS · NO_SABER | NO_SABER |
| ALGUIEN | Una persona, sin decir quién. | *PERSONA · *SIN · *DECIR · QUIEN | (sobre todo señas por incorporar) |
| ALGUN | Uno, cualquiera, sin decir cuál. | 1 · CUALQUIERA · NO · *DECIR · CUAL | NO |
| ALGUNAS | Uno, cualquiera, sin decir cuál. | 1 · CUALQUIERA · NO · *DECIR · CUAL | NO |
| ALGUNO | Uno, cualquiera, sin decir cuál. | 1 · CUALQUIERA · NO · *DECIR · CUAL | NO |
| ALODIAL | «Certificado alodial»: dice qué propiedades tiene una persona y si tienen deudas o hipotecas. | CERTIFICADO · *PROPIEDAD · *PERSONA · DEUDA · *HIPOTECA | (sobre todo señas por incorporar) |
| AMBITO | El área o espacio donde vale algo. | *ESPACIO · *VALE · *ALGO | (sobre todo señas por incorporar), (ninguna seña) |
| ANTECEDENTES | Lo que pasó antes. «Antecedentes penales»: registro de si una persona tuvo procesos penales. | PASADO · *REGISTRO · *PERSONA · *PROCESO · *PENAL · TENER | (sobre todo señas por incorporar), PASADO, TENER |
| ANTES | En un tiempo que ya pasó, primero. | PASADO · *PRIMERO | PASADO |
| ANTICIPO | Dar algo antes del tiempo normal. «Anticipo de legítima»: dar a un hijo parte de su herencia en vida. | *ANTES · *TIEMPO · NORMAL · DAR · *LEGITIMA · PARTE · HIJO · VIDA · HERENCIA | DAR |
| ANTICRESIS | Contrato: una persona usa una casa a cambio de prestar dinero al dueño; al devolver el dinero, deja la casa. | CONTRATO · *PERSONA · CASA · USAR · CAMBIAR · PRESTAR · BILLETES · *DUEÑO · DEVOLVER · DEJAR · CASA | USAR |
| ANTICRETICOS | Contrato: una persona usa una casa a cambio de prestar dinero al dueño; al devolver el dinero, deja la casa. | CONTRATO · *PERSONA · CASA · USAR · CAMBIAR · PRESTAR · BILLETES · *DUEÑO · DEVOLVER · DEJAR · CASA | USAR |
| ANTIGUA | Vieja, de hace mucho tiempo. | *ANTIGUO · *TIEMPO · MUCHO | (sobre todo señas por incorporar) |
| ANTIGUO | Vieja, de hace mucho tiempo. | *ANTIGUO · *TIEMPO · MUCHO | (usa ANTIGUO), (sobre todo señas por incorporar) |
| APORTAR | Dar o llevar algo que sirve, por ejemplo datos o pruebas. | DAR · LLEVAR · COSAS · *SERVIR | DAR, COSAS |
| ARCHIVAR | Guardar documentos en un archivo porque el trámite terminó o se paró. | PAPEL · GUARDAR · *ARCHIVO · TRAMITE · TERMINAR · *PARAR · POR_QUE | POR_QUE |
| ASEGURAR | Hacer que algo pase seguro. | HACER · *SEGURIDAD · *PASAR | (sobre todo señas por incorporar) |
| ASUMIR | Pensar que algo es verdad sin comprobarlo. | PENSAR · VERDAD · *COMPROBAR · NO | NO |
| ATENCION | El servicio que da una oficina a la persona que llega. | OFICINA · *PERSONA · LLEGAR · *SERVICIO · DAR | DAR |
| AUTOMATICO | Que pasa solo, sin hacer un trámite nuevo. | TRAMITE · NUEVO · NO · HACER | NO |
| AYUDA | Lo que una persona da a otra para resolver algo. | *PERSONA · DAR · *OTRO · *RESOLVER · COSAS | (sobre todo señas por incorporar), DAR, COSAS |
| BENEFICIARIO | Persona que recibe algo, por ejemplo una propiedad o un pago. | *PERSONA · RECIBIR · *PROPIEDAD · BILLETES | BILLETES |
| BIEN | Correcto, sin error. | *BIEN · *SIN · *ERROR | (usa BIEN), (sobre todo señas por incorporar), (ninguna seña) |
| BOLETA | Papel que muestra que algo se pagó o se observó. | PAPEL · MOSTRAR · *PAGAR · OBSERVAR | MOSTRAR |
| BORRAR | Quitar algo para que ya no exista, por ejemplo un mensaje. | *QUITAR · *EXISTIR · NO · PARA_QUE | PARA_QUE |
| CADA | Uno por uno, todos. | 1 · *TODOS | (ninguna seña) |
| CALIFICAR | Evaluar a una persona y darle un resultado. Ej.: el grado de discapacidad. | EVALUAR · *PERSONA · DAR · RESULTADO | DAR |
| CANAL | Medio para comunicarse: en persona, por teléfono, por internet. | *COMUNICARSE · *PERSONA · LLAMAR · INTERNET | LLAMAR |
| CANCELACION | Cuando algo termina o se borra del registro, por ejemplo una hipoteca pagada. | *ALGO · TERMINAR · *BORRAR · *REGISTRO · EJEMPLO · *HIPOTECA · *PAGAR | (sobre todo señas por incorporar) |
| CANCELAR | Terminar o borrar algo. «Cancelar una hipoteca»: quitarla del registro cuando la deuda se pagó. | TERMINAR · *BORRAR · *ALGO · *CANCELAR · *HIPOTECA · *QUITARLA · *REGISTRO · CUANDO · DEUDA · *PAGO | (usa CANCELAR), (sobre todo señas por incorporar), CUANDO |
| CARA | Parte del cuerpo con la boca y los ojos. | *CUERPO · BOCA · *OJO | (sobre todo señas por incorporar) |
| CATARSTRAL | Del catastro: el registro de la municipalidad con el tamaño y la ubicación de terrenos y casas. | *CATASTRO · *REGISTRO · *MUNICIPALIDAD · *TAMAÑO · *UBICACION · TERRENO · CASA | (sobre todo señas por incorporar) |
| CATASTRAL | Del catastro: el registro de la municipalidad con el tamaño y la ubicación de terrenos y casas. | *CATASTRO · *REGISTRO · *MUNICIPALIDAD · *TAMAÑO · *UBICACION · TERRENO · CASA | (sobre todo señas por incorporar) |
| CEDULA | El carnet de identidad, con su nombre y su foto. | PAPEL · IDENTIDAD · NOMBRE · FOTOS | PAPEL |
| CENTRO | El medio de algo. | *MEDIO | (sobre todo señas por incorporar), (ninguna seña) |
| CERRADO | La oficina no atiende: nadie puede entrar. | OFICINA · ATENDER · NO · *ENTRAR · PUEDO · NO | ATENDER, PUEDO |
| CIEN | El número 100. | 1 · 0 · 0 | (ninguna seña) |
| CITAR | Llamar a una persona para que vaya a un lugar un día y hora, por ejemplo al juzgado. | LLAMAR · *PERSONA · *LUGAR · DIA · HORA · JUZGADO · PARA_QUE | PARA_QUE |
| CIVIL | De la vida de las personas como ciudadanos. «Estado civil»: si una persona es soltera, casada, divorciada o viuda. | *PERSONA · *CIUDADANO · *ESTADO_CIVIL · SOLTERO · CASADO · *DIVORCIADO · VIUDA | (sobre todo señas por incorporar) |
| CODIGO | Número o letras que identifican algo. | *NUMERO · *LETRA · IDENTIFICAR | (sobre todo señas por incorporar) |
| COMPLETO | Que tiene todo. | *TODO · TENER | TENER |
| COMPRA | Cuando una persona paga para que algo sea suyo. | *PERSONA · *PAGAR · *PROPIEDAD · TENER · PARA_QUE | (sobre todo señas por incorporar), TENER, PARA_QUE |
| COMPROBANTE | Papel que demuestra que algo se hizo o se pagó. | PAPEL · *DEMOSTRAR · *HECHO · *PAGAR | (sobre todo señas por incorporar) |
| COMUN | Que es de muchas personas, no de una sola. | MUCHO · *PERSONA · NO · 1 | MUCHO |
| COMUNICACION | Entenderse con otra persona, en señas, por escrito o hablando. | COMPRENDER · *OTRO · *PERSONA · *SEÑA · ESCRIBIR · HABLAR | COMPRENDER |
| COMUNICARSE | Entenderse con otra persona, en señas, por escrito o hablando. | COMPRENDER · *OTRO · *PERSONA · *SEÑA · ESCRIBIR · HABLAR | COMPRENDER |
| CONCEPTO | El motivo de un pago: lo que se está pagando. | *PAGO · *MOTIVO · *PAGAR | (sobre todo señas por incorporar), (ninguna seña) |
| CONFIRMAR | Comprobar que algo es correcto o seguro. | *COMPROBAR · CORRECTO · *SEGURO | (sobre todo señas por incorporar) |
| CONJUNTO | Varias cosas en un mismo grupo. | VARIOS · COSAS · MISMO · GRUPO | VARIOS |
| CONMIGO | Con la persona que habla: «la tengo conmigo» es «la tengo yo, aquí». | YO · TENER · ELLA · AQUI | TENER, ELLA |
| CONSTANCIA | Papel que demuestra que algo pasó. Ej.: que una oficina recibió sus documentos. | PAPEL · *DEMOSTRAR · PASADO · OFICINA · RECIBIR | PASADO |
| CONSTANTE | Que pasa muchas veces, sin parar. | *MUCHOS · *VEZ · CONTINUAR · NO | CONTINUAR, NO |
| CONSULTAR | Preguntar o buscar información. | *PREGUNTAR · BUSCAR · *INFORMACION | (sobre todo señas por incorporar) |
| CONTACTO | Forma de comunicarse con una persona: un teléfono, un correo o un lugar. | *COMUNICARSE · *PERSONA · CELULAR · CORREO · *LUGAR | (sobre todo señas por incorporar), CELULAR |
| CONTAR | Explicar lo que pasó. | EXPLICAR · PASADO | PASADO |
| CONTEMPLAR | Una ley contempla algo cuando lo incluye o lo permite. | *LEYES · *INCLUIR · *PERMITIR | (sobre todo señas por incorporar), (ninguna seña) |
| CORRESPONDER | Ser el que toca o el que es; estar relacionado. Ej.: esa matrícula es de esa casa. | *RELACIONADO | (sobre todo señas por incorporar), (ninguna seña) |
| CORRESPONDIENTE | Ser el que toca o el que es; estar relacionado. Ej.: esa matrícula es de esa casa. | *RELACIONADO | (sobre todo señas por incorporar), (ninguna seña) |
| COSTO | Lo que hay que pagar; el precio. | *PAGAR · *PRECIO | (sobre todo señas por incorporar), (ninguna seña) |
| CUIDADO | Atención para que todo salga bien. | *ATENCION · *BIEN · PARA_QUE | (sobre todo señas por incorporar), PARA_QUE |
| DECIR | Comunicar algo a otra persona. | *OTRA · *PERSONA · COSAS · COMUNICAR | COSAS |
| DEFENDER | Ayudar a una persona para que no le hagan daño. | *PERSONA · DAÑAR · NO · PARA_QUE | PARA_QUE |
| DEFENSA | Ayuda de un abogado para una persona denunciada o acusada en un proceso. | AYUDAR · ABOGADO · *PERSONA · *DENUNCIAR · *ACUSAR · *PROCESO | (sobre todo señas por incorporar) |
| DEFENSOR | Abogado que defiende a una persona en un proceso. | ABOGADO · *DEFENDER · *PERSONA · *PROCESO | (sobre todo señas por incorporar) |
| DEFUNCION | La muerte de una persona. «Certificado de defunción»: documento que dice que murió. | *MUERTE · *PERSONA · CERTIFICADO · *DEFUNCION · PAPEL · *DECIR · MORIR | (usa DEFUNCION), (sobre todo señas por incorporar), MORIR |
| DEMORAR | Tardar mucho tiempo. | MUCHO · *TIEMPO · *TARDAR | (sobre todo señas por incorporar) |
| DEMOSTRAR | Mostrar algo para que vean que es verdad. | VER · VERDAD · MOSTRAR · PARA_QUE | PARA_QUE |
| DENUNCIA | Avisar a la policía o la fiscalía de un delito para que lo investiguen. | POLICIA · FISCALIA · *DELITO · INVESTIGACION · AVISAR · PARA_QUE | PARA_QUE |
| DENUNCIADO | Persona acusada en una denuncia. | *PERSONA · *ACUSAR · *DENUNCIA | (sobre todo señas por incorporar), (ninguna seña) |
| DENUNCIAR | Avisar a la policía o la fiscalía de un delito para que lo investiguen. | POLICIA · FISCALIA · *DELITO · INVESTIGACION · AVISAR · PARA_QUE | PARA_QUE |
| DEPARTAMENTO | Cada una de las 9 regiones de Bolivia, como Cochabamba. También: vivienda dentro de un edificio. | *CADA · 1 · 9 · *REGIONES · BOLIVIA · COMO · COCHABAMBA · *TAMBIEN · *VIVIENDA · DENTRO · *EDIFICIO | COMO |
| DESCRIBIR | Decir cómo es algo. | *DECIR · COMO · *ALGO | (sobre todo señas por incorporar) |
| DESCUENTO | Pagar menos de lo normal. | *PAGAR · *MENOS · NORMAL | (sobre todo señas por incorporar) |
| DESEA | Querer algo. «¿Desea…?» es «¿Quiere…?». | QUERER · QUE · QUIEN | QUE, QUIEN |
| DETERIORADO | Dañado, roto o gastado. | DAÑAR · *ROTO · *GASTAR | (sobre todo señas por incorporar), DAÑAR |
| DETERIORO | Dañado, roto o gastado. | DAÑAR · *ROTO · *GASTAR | (sobre todo señas por incorporar), DAÑAR |
| DICE | Comunicar algo a otra persona. | *OTRA · *PERSONA · COSAS · COMUNICAR | COSAS |
| DIRECTAMENTE | Sin otra persona en el medio; uno mismo. | *UNO_MISMO | (sobre todo señas por incorporar), (ninguna seña) |
| DISCAPACIDAD | Condición de una persona que tiene limitaciones; las personas sordas pueden tener carnet de discapacidad. | *PERSONA · *LIMITACION · SORDO · PAPEL · IDENTIDAD · *DISCAPACIDAD · TENER | (usa DISCAPACIDAD), PAPEL |
| DISPONIBLE | Que se puede usar ahora. | AHORA · USAR · PUEDO | PUEDO |
| DIVORCIADO | Persona que ya no está casada: se separó por ley. | SEPARADOS · LEY | (negación perdida) |
| DONACION | Dar algo gratis a otra persona, por ejemplo una casa. | *OTRA · *PERSONA · GRATIS · DAR | DAR |
| DOS | El número 2. | 2 | (ninguna seña) |
| DUDAR | No estar seguro de algo. | NO · *SEGURIDAD · TENER | TENER |
| DUEÑO | Persona que tiene algo: es suyo. | TENER · SUYO | TENER |
| ELEGIR | Decidir cuál quiere entre varios. | DECIDIR · QUE · QUERER · VARIOS | QUE, QUERER |
| ENCONTRAR | Hallar algo que se buscaba. | BUSCAR · ENCONTRARSE | ENCONTRARSE |
| ENTONCES | Une una idea con lo que se dijo antes: «por eso», «en ese caso». | *ESE · *CASO | (sobre todo señas por incorporar), (ninguna seña) |
| ENTRAR | Ir adentro de un lugar. | DENTRO · IR | DENTRO |
| ENTRE | En el medio de una cosa y otra. | *MEDIO · COSAS · *OTRO | (sobre todo señas por incorporar) |
| ENTREGA | Cuando se da algo a la persona. | *PERSONA · DAR | DAR |
| EQUIVOCADO | Que no es correcto; que tiene un error. | NO · CORRECTO · *ERROR · TENER | TENER |
| ESA | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| ESE | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| ESO | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| ESOS | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| ESPACIO | Lugar vacío. | *LUGAR · *VACIO | (sobre todo señas por incorporar), (ninguna seña) |
| ESPACIOS | Lugares vacíos entre letras o números. | *LUGAR · *VACIO · *ENTRE · *LETRA · *NUMERO | (sobre todo señas por incorporar), (ninguna seña) |
| ESPECIALIZADO | Que se ocupa solo de un tipo de casos. | *CASO · *OCUPAR · *SOLO · *TIPO | (sobre todo señas por incorporar), (ninguna seña) |
| ESPECIFICO | Propio de una sola cosa; uno exacto. | 1 · *EXACTO | (ninguna seña) |
| ESTA | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| ESTE | Señala algo que ya se mencionó. En LSB se indica señalando. | *SEÑALAR · *YA · *MENCION | (sobre todo señas por incorporar), (ninguna seña) |
| EXACTO | Justo, sin error. | *JUSTO · *ERROR · NO | (sobre todo señas por incorporar), NO |
| EXPLICACION | Lo que se dice o se escribe para que alguien entienda algo. | EXPLICAR · *ENTENDER · PARA_QUE | EXPLICAR, PARA_QUE |
| FALLECIDO | Persona que murió. | *PERSONA · MORIR | MORIR |
| FAMILIA | Padres, hijos, hermanos y demás parientes. | *PADRE · HIJA · HERMANO · PARIENTE | HIJA |
| FAMILIAR | De la familia. «Audiencia familiar»: en un juzgado de familia. | *FAMILIA · *AUDIENCIA · JUZGADO · *FAMILIA | (sobre todo señas por incorporar) |
| FISCAL | Persona del Ministerio Público que investiga los delitos y acusa ante el juez. | *MINISTERIO_PUBLICO · *DELITO · *INVESTIGAR · JUEZ · *ACUSAR | (sobre todo señas por incorporar) |
| FISICA | En papel o en material, no digital. «Cédula física»: la tarjeta de la cédula. | PAPEL · MATERIAL · NO · *DIGITAL · *CEDULA · *FISICA · *TARJETA · IDENTIDAD | (usa FISICA), IDENTIDAD |
| FOLIO_REAL | Documento de Derechos Reales con los datos de una propiedad: dueño, ubicación, hipotecas. | PAPEL · *DERECHOS_REALES · *PROPIEDAD · *DATOS · *DUEÑO · *UBICACION · *HIPOTECA | (sobre todo señas por incorporar) |
| GARANTIA | Algo que se deja para asegurar que se va a pagar. | *PAGAR · *ASEGURAR | (sobre todo señas por incorporar), (ninguna seña) |
| GESTION | Trámite o tarea que se hace. También: año de impuestos («gestión 2023»). | TRAMITE · HACER · AÑO · IMPUESTO · *GESTION · 2 · 0 · 2 · 3 | (usa GESTION) |
| GRADO | Nivel o medida. Ej.: el grado de discapacidad. | *NIVEL · *MEDIDA | (sobre todo señas por incorporar), (ninguna seña) |
| GRAVAMEN | Carga o deuda que tiene una propiedad, por ejemplo una hipoteca. | *PROPIEDAD · DEUDA · TENER | TENER |
| GRAVAMENES | Carga o deuda que tiene una propiedad, por ejemplo una hipoteca. | *PROPIEDAD · DEUDA · TENER | TENER |
| GUIONES | La raya corta «-» que separa números o letras. | *RAYA · *CORTAR | (sobre todo señas por incorporar), (ninguna seña) |
| HECHO | Lo que pasó. | PASADO · *SUCEDER | PASADO |
| HEREDAR | Recibir los bienes de una persona que murió. | RECIBIR · *BIENES · *PERSONA · MORIR | MORIR |
| HEREDERO | Persona que recibe los bienes de alguien que murió. | *MUERTO · *BIENES · RECIBIR · *PERSONA | (sobre todo señas por incorporar) |
| HUBO | Que algo pasó o existió antes. «¿Hubo violencia?»: «¿Pasó violencia?». | VIOLENCIA · *PASAR · DONDE | DONDE |
| INCUMPLIMIENTO | Cuando alguien no hace lo que una orden o un acuerdo obliga a hacer. | *ORDEN · *ACUERDO · *OBLIGAR · HACER · NO | (sobre todo señas por incorporar) |
| INCUMPLIR | No hacer lo que una orden o un acuerdo obliga a hacer. | NO · HACER · *ORDEN · *ACUERDO · *OBLIGAR | (sobre todo señas por incorporar) |
| INDEPENDIENTE | Separado, solo, que no depende de otro. | *SEPARADO · *SOLO | (sobre todo señas por incorporar), (ninguna seña), (negación perdida) |
| INDICAR | Decir o mostrar algo a otra persona. | *DECIR · MOSTRAR · *OTRO · *PERSONA | (sobre todo señas por incorporar) |
| INDICARME | Decir o mostrar algo a otra persona. | *DECIR · MOSTRAR · *OTRO · *PERSONA | (sobre todo señas por incorporar) |
| INFORMACION | Datos o noticias sobre algo. | *NOTICIAS · *SOBRE · *ALGO | (sobre todo señas por incorporar), (ninguna seña) |
| INFORMACION_RAPIDA | Servicio de Derechos Reales para consultar rápido los datos de una propiedad. | *SERVICIO · *DERECHOS_REALES · *CONSULTAR · RÁPIDO · *DATOS · *PROPIEDAD | (sobre todo señas por incorporar) |
| INFORMAR | Dar a conocer una información. | *INFORMACION · DAR | DAR |
| INFORME | Documento que explica algo. «Informe médico»: documento del médico sobre la salud. | PAPEL · EXPLICAR · *ALGO · *INFORME · *MEDICO · *MEDICO · *SALUD | (usa INFORME), (sobre todo señas por incorporar) |
| INTEGRAL | Completo, que atiende todo. | *COMPLETO · ATENDER · *TODO | (sobre todo señas por incorporar), ATENDER |
| INTENCION | Lo que una persona quiere hacer. | *PERSONA · QUERER · HACER | QUERER |
| INTERPRETAR | Pasar lo que se dice de una lengua a otra, por ejemplo de español a LSB. | *TRADUCIR · *LENGUA · *OTRO | (sobre todo señas por incorporar), (ninguna seña) |
| INTIMIDAD | Lo privado de una persona: su cuerpo y su vida. | *PERSONA · *CUERPO · VIDA · *PRIVADO | (sobre todo señas por incorporar) |
| LENGUA | Idioma. «Lengua de señas»: la lengua de las personas sordas. | *LENGUA_DE_SEÑAS · SORDO · *PERSONA | (sobre todo señas por incorporar) |
| LEYES | Las reglas del país que todos deben cumplir. | *PAIS · *TODOS · CUMPLIR · *DEBER | (sobre todo señas por incorporar) |
| LUGAR | Sitio, espacio. | *LUGAR · *ESPACIO | (usa LUGAR), (sobre todo señas por incorporar), (ninguna seña) |
| MANTENER | Seguir igual, no cambiar. | COMO_ESTAS | COMO_ESTAS, (negación perdida) |
| MARGINAL | «Nota marginal»: algo escrito al costado de un registro para corregirlo o agregar datos. | *NOTA · *MARGINAL · ESCRIBIR · AL_LADO · *REGISTRO · *CORREGIR · *AGREGAR · *DATOS | (usa MARGINAL), (sobre todo señas por incorporar), AL_LADO |
| MAS | Mayor cantidad. | MUCHO · *CANTIDAD | MUCHO |
| MATRICULA | Número con que Derechos Reales registra una propiedad. | *NUMERO · *DERECHOS_REALES · *REGISTRAR · *PROPIEDAD | (sobre todo señas por incorporar), (ninguna seña) |
| MATRICULACION | Darle número de matrícula a una propiedad con registro antiguo. | *PROPIEDAD · *REGISTRO · *ANTIGUO · *NUMERO · DAR | (sobre todo señas por incorporar), DAR |
| MATRICULAR | Darle número de matrícula a una propiedad con registro antiguo. | *PROPIEDAD · *REGISTRO · *ANTIGUO · *NUMERO · DAR | (sobre todo señas por incorporar), DAR |
| MEDICA | De la salud o del médico. «Atención médica»: que un médico la revise. | MEDICINA · ATENDER | ATENDER |
| MEDICO | Del médico. «Certificado médico»: documento del médico sobre la salud. | *MEDICO · CERTIFICADO · *MEDICO · *SALUD · PAPEL | (usa MEDICO), (sobre todo señas por incorporar) |
| MENCION | Cuando un documento nombra algo. | CUANDO · PAPEL · *NOMBRAR · *ALGO | CUANDO |
| MENCIONAR | Cuando un documento nombra algo. | CUANDO · PAPEL · *NOMBRAR · *ALGO | CUANDO |
| MENTE | Lo que una persona piensa y siente. | PENSAR · SENTIR | PENSAR, SENTIR |
| MOTIVO | Por qué pasa algo. | POR_QUE · *PASAR · *ALGO | (sobre todo señas por incorporar) |
| MOTO | Motocicleta: vehículo de dos ruedas con motor. | MOTOCICLETA · *VEHICULO · *DOS · *RUEDA · *MOTOR | (sobre todo señas por incorporar) |
| MUCHOS | Varios, una cantidad grande. | VARIOS · MUCHO | MUCHO |
| MUERTO | Persona que ya no vive. | *PERSONA · VIVIR · NO | VIVIR |
| NACIMIENTO | Cuando una persona nace. «Certificado de nacimiento»: documento que dice dónde y cuándo nació. | *PERSONA · *NACER · CERTIFICADO · *NACIMIENTO · DONDE · CUANDO | (usa NACIMIENTO) |
| NADA_MAS | Solo eso. | *SOLO · *ESO | (sobre todo señas por incorporar), (ninguna seña) |
| NADIE | Ni una persona. | *PERSONA | (sobre todo señas por incorporar), (ninguna seña) |
| NEGAR | Decir que no; no dar algo. Ej.: no dar atención. | *DECIR · NO · DAR | DAR |
| NINGUNA | Ni una. | 1 · NO | NO |
| NIÑEZ | Edad de los niños y niñas. | EDAD · NIÑO · MUCHO | MUCHO |
| NOTARIAL | De la notaría. «Documento notarial»: documento hecho ante un notario. | *NOTARIA · PAPEL · *NOTARIAL | (usa NOTARIAL), (sobre todo señas por incorporar) |
| NOTARIO | Persona autorizada para hacer escrituras y certificar firmas y documentos. | *AUTORIZADO · *ESCRITURA · *CERTIFICAR · *FIRMA · PAPEL | (sobre todo señas por incorporar) |
| NOTICIAS | Lo nuevo que se sabe de algo que pasó. | NUEVO · SABER · PASADO · *ALGO | PASADO |
| NOTIFICACION | Aviso oficial escrito de una institución sobre un trámite o un proceso. | INSTITUCION · TRAMITE · *PROCESO · AVISAR · OFICIAL · PAPEL · ESCRIBIR | AVISAR, PAPEL |
| NUMERO | Número. | *NUMERO | (usa NUMERO), (sobre todo señas por incorporar), (ninguna seña) |
| OBLIGAR | Hacer que otra persona haga algo que no quiere. | HACER · *OTRO · *PERSONA · HACER · *ALGO · NO · QUERER | QUERER |
| OBTENER | Conseguir algo. | *CONSEGUIR | (sobre todo señas por incorporar), (ninguna seña) |
| OCURRIDO | Pasar, suceder. | *SUCEDER · *PASAR | (sobre todo señas por incorporar), (ninguna seña) |
| OCURRIR | Pasar, suceder. | *SUCEDER · *PASAR | (sobre todo señas por incorporar), (ninguna seña) |
| OFRECER | Dar o poner algo a disposición. | DAR · *DISPONER | DAR |
| OPCION | Una de las posibilidades para elegir. | *POSIBILIDAD · *ELEGIR | (sobre todo señas por incorporar), (ninguna seña) |
| OTRA | Una distinta. | DIFERENTE | DIFERENTE |
| OTRAS | Una distinta. | DIFERENTE | DIFERENTE |
| OTRO | Una distinta. | DIFERENTE | DIFERENTE |
| OTROS | Una distinta. | DIFERENTE | DIFERENTE |
| PAGAR | Dar dinero por algo. | DAR · BILLETES · *ALGO | DAR |
| PAGO | Dar dinero por algo. | DAR · BILLETES · *ALGO | DAR |
| PARADERO | El lugar donde está una persona. | *LUGAR · *PERSONA | (sobre todo señas por incorporar), (ninguna seña) |
| PARTICION | Dividir una propiedad o herencia en partes, una para cada dueño. | *PROPIEDAD · HERENCIA · PARTE · *CADA · *PROPIETARIO | (sobre todo señas por incorporar) |
| PARTICIONAR | Dividir una propiedad o herencia en partes, una para cada dueño. | *PROPIEDAD · HERENCIA · PARTE · *CADA · *PROPIETARIO | (sobre todo señas por incorporar) |
| PARTIDA | Número de registro antiguo de una propiedad en Derechos Reales. | *PROPIEDAD · *REGISTRO · *ANTIGUO · *DERECHOS_REALES | (sobre todo señas por incorporar), (ninguna seña) |
| PASAR | Cambiar algo de lugar o de dueño. «Pasar a mi nombre»: registrarlo como mío. | CAMBIAR · *LUGAR · *PROPIETARIO | (sobre todo señas por incorporar) |
| PATROCINIO | Que un abogado lleve y defienda el caso de una persona. | ABOGADO · *CASO · *DEFENDER · *PERSONA | (sobre todo señas por incorporar) |
| PENAL | Sobre delitos. | *DELITO | (sobre todo señas por incorporar), (ninguna seña) |
| PENDIENTE | Que falta hacer o pagar. | AUSENTE · HACER · *PAGAR | AUSENTE |
| PERTENECER | Ser de alguien. | *ALGUIEN | (sobre todo señas por incorporar), (ninguna seña) |
| PISO | Cada nivel de un edificio. | *EDIFICIO · *NIVEL | (sobre todo señas por incorporar), (ninguna seña) |
| PLACA | Chapa con el número de un vehículo. | *VEHICULO · *NUMERO | (sobre todo señas por incorporar), (ninguna seña) |
| PODER | Poder hacer algo. También: documento para que otra persona haga trámites por uno. | PARA_QUE | PARA_QUE |
| PODRÉ | Poder hacer algo. También: documento para que otra persona haga trámites por uno. | PARA_QUE | PARA_QUE |
| PONER | Colocar. «Ponerla a mi nombre»: registrar la propiedad como mía. | *PONER · *PROPIEDAD · MIO | (usa PONER), (sobre todo señas por incorporar) |
| POSIBILIDAD | Algo que puede pasar. | *PODER · *PASAR | (sobre todo señas por incorporar), (ninguna seña) |
| PRECIO | Lo que cuesta algo. | *ALGO · *COSTO | (sobre todo señas por incorporar), (ninguna seña) |
| PREFERIR | Querer una cosa más que otra. | QUERER · COSAS · *MAS · QUE · *OTRO | QUE |
| PREFIERES | Querer una cosa más que otra. | QUERER · COSAS · *MAS · QUE · *OTRO | QUE |
| PREGUNTA | Lo que se dice para saber algo. | SABER · PALABRA | PALABRA |
| PREGUNTAR | Lo que se dice para saber algo. | SABER · PALABRA | PALABRA |
| PRESENCIAL | En persona, yendo al lugar. | *PERSONA · IR · *LUGAR | (sobre todo señas por incorporar) |
| PRESENCIALMENTE | En persona, yendo al lugar. | *PERSONA · IR · *LUGAR | (sobre todo señas por incorporar) |
| PREVENIR | Cuidar antes para estar seguro. | CUIDAR · *ANTES · *SEGURIDAD | (sobre todo señas por incorporar) |
| PRIMERO | Antes que lo demás. | *ANTES | (sobre todo señas por incorporar), (ninguna seña) |
| PRIVADO | Hecho entre personas, sin notario. «Contrato privado». | *PERSONA · CONTRATO · *PRIVADO | (usa PRIVADO), (sobre todo señas por incorporar) |
| PROCEDIMIENTO | Pasos que hay que seguir. | *PASO · *SEGUIR | (sobre todo señas por incorporar), (ninguna seña) |
| PROPIEDAD | Lo que es de una persona, por ejemplo una casa o un terreno. | *PERSONA · *PROPIEDAD · *CASO · EJEMPLO · *CASO · TERRENO | (usa PROPIEDAD), (sobre todo señas por incorporar) |
| PROPIEDAD_HORIZONTAL | Forma de ser dueño de un departamento dentro de un edificio que tiene partes comunes. | *DEPARTAMENTO · *EDIFICIO · PARTE · *COMUN · *PROPIETARIO | (sobre todo señas por incorporar) |
| PROPIETARIO | Dueño. | *PROPIETARIO | (usa PROPIETARIO), (sobre todo señas por incorporar), (ninguna seña) |
| PROPIO | De uno mismo. «Con sus propias palabras»: como usted lo diga. | *PROPIO · PALABRA · COMO · TU · *DECIR | (usa PROPIO), COMO |
| PROTECCION | Cuidado para que una persona no sufra daño. «Medidas de protección»: órdenes de una autoridad para cuidar a una persona. | CUIDAR · *PERSONA · DAÑAR · NO · *MEDIDA · *PROTECCION · *ORDEN · AUTORIDAD · *PERSONA · PARA_QUE | (usa PROTECCION), PARA_QUE |
| PSICOLOGICA | De la mente y las emociones. «Ayuda psicológica»: apoyo de un psicólogo. | *MENTE · EMOCIÓN · *PSICOLOGO · *APOYO | (sobre todo señas por incorporar) |
| PSICOLOGICO | De la mente y los sentimientos. «Apoyo psicológico»: ayuda de un psicólogo. | *MENTE · *SENTIMIENTO · *AYUDA · *PSICOLOGO | (sobre todo señas por incorporar), (ninguna seña) |
| PUBLICA | Del Estado o para todos. «Escritura pública»: hecha ante notario. | *ESTADO · *TODOS · *ESCRITURA_PUBLICA · *NOTARIO · HACER | (sobre todo señas por incorporar), HACER |
| QUEDA | Estar ubicado. «Queda entre…»: está entre… | *UBICADO · *ENTRE | (sobre todo señas por incorporar), (ninguna seña) |
| RADICAR | Estar registrado en un lugar. «Vehículo radicado en Cochabamba». | *LUGAR · *REGISTRADO · *VEHICULO · COCHABAMBA | (sobre todo señas por incorporar) |
| RECEPCION | Cuando una oficina recibe documentos o atiende a las personas. | OFICINA · PAPEL · RECIBIR · *PERSONA · ATENDER | ATENDER |
| RECLAMO | Queja formal por un mal servicio o un error. | QUEJAR · *FORMAL · MAL · *SERVICIO · *ERROR | (sobre todo señas por incorporar) |
| RECOCNER | Aceptar como propio. «Reconocer firmas»: confirmar ante notario que la firma es suya. | ACEPTAR · SUYO | SUYO |
| RECONOCER | Aceptar como propio. «Reconocer firmas»: confirmar ante notario que la firma es suya. | ACEPTAR · SUYO | SUYO |
| RECONOCIMIENTO | «Reconocimiento de firmas»: el notario confirma que una firma es de esa persona. | *CONFIRMAR · *FIRMA · *PERSONA | (sobre todo señas por incorporar), (ninguna seña) |
| REEMPLAZAR | Poner uno nuevo en lugar del anterior. | NUEVO · *LUGAR · *ANTERIOR · *PONER | (sobre todo señas por incorporar) |
| REGIMEN | Conjunto de reglas para algo. | *CONJUNTO · REGLA · *ALGO | (sobre todo señas por incorporar) |
| REGISTRADO | Anotar algo en un libro o sistema oficial, por ejemplo quién es dueño de una casa. | LIBRO · *SISTEMA · OFICIAL · *CASO · *PROPIETARIO · *CASO · ESCRIBIR | (sobre todo señas por incorporar), ESCRIBIR |
| REGISTRAL | Anotar algo en un libro o sistema oficial, por ejemplo quién es dueño de una casa. | LIBRO · *SISTEMA · OFICIAL · *CASO · *PROPIETARIO · *CASO · ESCRIBIR | (sobre todo señas por incorporar), ESCRIBIR |
| REGISTRAR | Anotar algo en un libro o sistema oficial, por ejemplo quién es dueño de una casa. | LIBRO · *SISTEMA · OFICIAL · *CASO · *PROPIETARIO · *CASO · ESCRIBIR | (sobre todo señas por incorporar), ESCRIBIR |
| REGISTRO | Anotar algo en un libro o sistema oficial, por ejemplo quién es dueño de una casa. | LIBRO · *SISTEMA · OFICIAL · *CASO · *PROPIETARIO · *CASO · ESCRIBIR | (sobre todo señas por incorporar), ESCRIBIR |
| REGULARIZACION | Arreglar los papeles de una propiedad para que estén según la ley. | ARREGLAR · PAPEL · *PROPIEDAD · LEY · PARA_QUE | PARA_QUE |
| REGULARIZAR | Arreglar los papeles de una propiedad para que estén según la ley. | ARREGLAR · PAPEL · *PROPIEDAD · LEY · PARA_QUE | PARA_QUE |
| RELACION | Unión entre personas, por ejemplo parentesco. | *PERSONA · *PARENTESCO · EJEMPLO | (sobre todo señas por incorporar) |
| RELATO | Explicación escrita o señada de lo que pasó. | ESCRIBIR · PASADO · *EVENTO | PASADO |
| RENOVACION | Hacer un documento nuevo cuando el anterior vence. | NUEVO · PAPEL · HACER · *ANTERIOR · *VENCER · CUANDO | CUANDO |
| RENOVAR | Hacer un documento nuevo cuando el anterior vence. | NUEVO · PAPEL · HACER · *ANTERIOR · *VENCER · CUANDO | CUANDO |
| REPOSICION | Sacar un documento nuevo porque el anterior se perdió, se robó o se dañó. | NUEVO · PAPEL · *SACAR · *ANTERIOR · PERDER · ROBAR · DAÑAR · POR_QUE | POR_QUE |
| REPRESENTACION | Actuar en nombre de otra persona, con su permiso. | *OTRA · *PERSONA · NOMBRE · PERMISO · HACER | HACER |
| REPRESENTACIÓN | Oficina que atiende en nombre de otra institución. | OFICINA · ATENDER · INSTITUCION · *OTRO · NOMBRE | ATENDER |
| RESELLADO | Volver a sellar un documento para confirmar o actualizar un registro. | VOLVER · SELLO · PAPEL · *CONFIRMAR · ACTUALIZAR · *REGISTRO | SELLO |
| RESPECTAR | Respetar: tratar bien a otra persona. | *OTRA · *PERSONA · *BIEN · *TRATAR | (sobre todo señas por incorporar), (ninguna seña) |
| RESSELLADO | Volver a sellar un documento para confirmar o actualizar un registro. | VOLVER · SELLO · PAPEL · *CONFIRMAR · ACTUALIZAR · *REGISTRO | SELLO |
| ROTO | Dañado, ya no funciona. | DAÑAR · FUNCIONAR · NO | DAÑAR |
| RUEDA | Lo que tiene un auto abajo para andar. | BAJO · ANDAR | BAJO |
| RUTA | Camino o pasos que se siguen. «Ruta de atención»: las oficinas que atienden un caso. | *CAMINO · *PASO · *SIGUIR · *RUTA · *ATENCION · OFICINA · *CASO · ATENDER | (usa RUTA), (sobre todo señas por incorporar), ATENDER |
| SALIR | Ir afuera, irse. | FUERA · IR | FUERA |
| SALUD | Cuando el cuerpo y la mente están bien. | *CUERPO · *MENTE · *BIEN | (sobre todo señas por incorporar), (ninguna seña) |
| SEDE | Oficina o lugar donde atiende una institución. | OFICINA · INSTITUCION · ATENDER | ATENDER |
| SEGUN | Lo que dice una persona o un papel. | PALABRA · *DECIR · *PERSONA · PAPEL | PALABRA |
| SEGURIDAD | Estar sin peligro. | *SEGURIDAD · NO | (usa SEGURIDAD), NO |
| SEGURO | Sin peligro. | PELIGROSO · NO | NO |
| SENTIMIENTO | Lo que una persona siente, como miedo o tristeza. | SENTIR · MIEDO · TRISTE | SENTIR |
| SERVIR | Ser útil, valer para algo. | *UTIL · *VALER · *ALGO | (sobre todo señas por incorporar), (ninguna seña) |
| SEXUAL | Del cuerpo y la intimidad de una persona. «Violencia sexual»: obligar a alguien a algo íntimo sin que quiera. | *PERSONA · *CUERPO · *INTIMIDAD · *VIOLENCIA_SEXUAL · *OBLIGAR · *ALGUIEN · *ALGO · *INTIMIDAD · NO · QUERER | (sobre todo señas por incorporar), NO, QUERER |
| SEÑAS | Señas: la forma de comunicarse de las personas sordas, con manos, cara y cuerpo. | *PERSONA · *SORDA · *COMUNICARSE · *MANO · *CARA · *CUERPO | (sobre todo señas por incorporar), (ninguna seña) |
| SIGUIENTE | El que viene después. | LUEGO · VENIR | LUEGO, VENIR |
| SIN | Que no tiene algo. | NO · TENER · *ALGO | TENER |
| SIRVE | Ser útil, valer para algo. | *UTIL · *VALER · *ALGO | (sobre todo señas por incorporar), (ninguna seña) |
| SISTEMA | Programa o página de computadora que usa una oficina. | COMPUTADORA · USAR · OFICINA | USAR |
| SOCIAL | De la sociedad o de la ayuda a las personas. «Trabajo social»: profesionales que orientan y ayudan. | *SOCIEDAD · *AYUDA · *PERSONA · *TRABAJADOR_SOCIAL · *ORIENTAR · AYUDAR | (sobre todo señas por incorporar) |
| SOCIEDAD | Las personas que viven en un lugar. | *PERSONA · VIVIR · *LUGAR | (sobre todo señas por incorporar), VIVIR |
| SOLICITANTE | Persona que pide algo. | PEDIR · *ALGO | PEDIR |
| SOLO | Únicamente, nada más. | *NADA_MAS | (sobre todo señas por incorporar), (ninguna seña) |
| SORDA | Persona que no oye. | SORDO | (negación perdida) |
| SUCEDER | Pasar, ocurrir. | *OCURRIR · *PASAR | (sobre todo señas por incorporar), (ninguna seña) |
| TARDAR | Demorar, necesitar tiempo. | *DEMORAR · *TIEMPO · NECESITAR | (sobre todo señas por incorporar) |
| TARJETA | Carnet pequeño, como la cédula. | PAPEL · IDENTIDAD · PEQUEÑO | PAPEL |
| TITULAR | La persona a cuyo nombre está algo, el dueño registrado. | *PERSONA · NOMBRE · TENER | TENER |
| TODAS | Sin que falte ninguna. | *SIN · *FALTE · *NINGUNA | (sobre todo señas por incorporar), (ninguna seña), (negación perdida) |
| TODO | Sin que falte ninguna. | *SIN · *FALTE · *NINGUNA | (sobre todo señas por incorporar), (ninguna seña), (negación perdida) |
| TODOS | Sin que falte ninguna. | *SIN · *FALTE · *NINGUNA | (sobre todo señas por incorporar), (ninguna seña), (negación perdida) |
| TRABAJADOR_SOCIAL | Persona que ayuda y orienta a las familias. | *FAMILIA · AYUDAR · *ORIENTAR | (sobre todo señas por incorporar) |
| TRABAJO | Lugar donde una persona trabaja, o lo que hace para ganar dinero. | *LUGAR · *TRABAJAR · GANAR_DINERO | (sobre todo señas por incorporar) |
| TRANSFERENCIA | Pasar algo de una persona a otra: dinero, o una propiedad al venderla. | *PASAR · *ALGO · *PERSONA · *OTRO · BILLETES · *PROPIEDAD · VENDER | (sobre todo señas por incorporar) |
| TRIBUNAL | Oficina de jueces. | OFICINA · JUEZ | JUEZ |
| USUCAPION | Ser dueño de una propiedad por haber vivido en ella muchos años, cuando un juez lo reconoce. | VIVIR · *PROPIEDAD · AÑO · MUCHO · JUEZ · *RECONOCER | VIVIR |
| UTIL | Que sirve para algo. | *SERVIR · *ALGO | (sobre todo señas por incorporar), (ninguna seña) |
| VACIO | Que no tiene nada adentro. | *NADA · DENTRO · NO · TENER | DENTRO, TENER |
| VALE | Que todavía se puede usar. | *TODAVIA · USAR · *PODER | (sobre todo señas por incorporar) |
| VALER | Poder usarse, servir. | *PODER · USAR · *SERVIR | (sobre todo señas por incorporar) |
| VALIDAR | Comprobar que algo es correcto y vale. | *COMPROBAR · *VALE | (sobre todo señas por incorporar), (ninguna seña) |
| VALIDO | Que sirve, que vale. | *VALE | (sobre todo señas por incorporar), (ninguna seña) |
| VEHICULO | Auto, moto o camión. | *MOTO · *CAMION | (sobre todo señas por incorporar), (ninguna seña) |
| VENTA | Cuando una persona da algo a cambio de dinero. | *PERSONA · DAR · BILLETES · CAMBIAR | DAR |
| VIAJE | Ir de un lugar a otro lejano. | IR · *LUGAR · *OTRO · LEJOS | LEJOS |
| VICTIMA | Persona que sufrió un delito. | *PERSONA · *DELITO · *SUFRI | (sobre todo señas por incorporar), (ninguna seña) |
| VIGENCIA | Tiempo en que un documento vale. | *TIEMPO · PAPEL · *VALE | (sobre todo señas por incorporar) |
| VIGENTE | Que todavía vale, que no venció. | *TODAVIA · *VALE · NO · *VENCER | (sobre todo señas por incorporar) |
| VIOLENCIA_SEXUAL | Tocar el cuerpo de una persona sin su permiso. | *PERSONA · *CUERPO · TOCAR · PERMISO · NO | NO |
| VIVIENDA | Casa o lugar donde vive una persona. | VIVIR · *LUGAR | VIVIR |
| YA | En este momento o antes; algo que ya pasó. | AHORA · *ANTES · PASADO | AHORA, PASADO |
