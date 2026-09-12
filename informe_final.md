(an UNIVERSIDAD CATOLICA Oi BOLIVIANA Na COCHABAMBA 

### **ÍNDICE GENERAL** 

|**ÍNDICE GENERAL................................................................................................... 2**|
|---|
|**INTRODUCCIÓN...................................................................................................... 6**|
|**1. MARCO CONTEXTUAL......................................................................................6**|
|**1.1. Antecedentes...................................................................................................6**|
|**_1.1.1. Antecedentes Nacionales....................................................................... 6_**|
|**_1.1.2. Antecedentes Internacionales................................................................9_**|
|**_Tabla 1...................................................................................................... 12_**|
|**_Tabla de análisis de sistemas similares disponibles a nivel global y local._**<br>**_12_**|
|**1.2. Problema......................................................................................................13**|
|**_1.2.1. Situación problemática........................................................................ 13_**|
|**_1.2.2. Formulación del problema.................................................................. 14_**|
|**1.3. Objetivos.......................................................................................................14**|
|**_1.3.1. Objetivo general................................................................................... 14_**|
|**_1.3.2. Objetivos específicos............................................................................ 14_**|
|**1.4. Alcances........................................................................................................ 15**|
|**1.5. Límites...........................................................................................................15**|
|**1.6. Justificación..................................................................................................15**|
|**2. MARCO TEÓRICO.............................................................................................17**|
|**2.1. Lengua de Señas Boliviana(LSB).............................................................. 17**|
|**_2.1.1. Naturaleza viso-gestual........................................................................17_**|
|**_2.1.2. Parámetros formacionales de la Seña.................................................18_**|
|**_Figura 1..............................................................................................18_**|
|**_Parámetros formacionales de la seña en LSB..................................18_**|
|**_2.1.3. Estructura gramatical y diferencias con el español escrito................19_**|
|**_2.1.4. Comprensión lectora del español escrito en l a comunidad sorda.....19_**|
|**2.2. Arquitectura del Software...........................................................................20**|
|**_Figura 2..............................................................................................20_**|
|**_Diagrama de Arquitectura Limpia (Clean Architecture).................20_**|
|**_2.2.1. Capa de Dominio (Domain Layer)......................................................21_**|
|**_2.2.2. Capa de Datos (Data Layer)................................................................ 21_**|
|**_2.2.3. Capa de Presentación (Presentation Layer)....................................... 22_**|
|**2.3. Metodología de desarrollo de Software......................................................22**|
|**_2.3.1. Visualización del flujo: Tablero Kanban.............................................22_**|
|**_2.3.2. Limitación del Trabajo en Curso (WIP)............................................. 23_**|
|**_2.3.3. Gestión del Flujo..................................................................................23_**|
|**2.4. Tecnologías de desarrollo de Backend........................................................23**|
|**Figura 3..............................................................................................24**|



|**Diagrama conceptual de la arquitectura Serverless en AWS para**|
|---|
|**OpenSoul............................................................................................24**|
|**_2.4.1. Amazon API Gateway (Interfaz de Comunicación y Seguridad).......24_**|
|**_2.4.2. AWS Lambda (Función como Servicio - FaaS)..................................24_**|
|**_2.4.3. Amazon Bedrock (Modelos Fundacionales y PLN)........................... 25_**|
|**_2.4.4. Amazon Polly (Síntesis de Voz - Salida Auditiva)...............................25_**|
|**_2.4.5. Amazon S3 (Almacenamiento de Objetos y Privacidad).................... 25_**|
|**2.5. Tecnologías de desarrollo de Frontend..................................................... 26**|
|**_2.5.1. Framework de desarrollo: Flutter.......................................................26_**|
|**_2.5.2. Gestión de Estado Reactiva: Riverpod (v3).........................................26_**|
|**_Figura 4..............................................................................................27_**|
|**_Flujo de gestión de estado con Riverpod en el módulo_**<br>**_lsb_to_text_audio............................................................................... 27_**|
|**_2.5.3. Síntesis y Reproducción de Audio: audio remoto y audio local.........28_**|
|**_2.5.4. Navegación Declarativa: GoRouter.................................................... 28_**|
|**2.6. Tecnologías de DBMS..................................................................................28**|
|**_2.6.1. Almacenamiento Local del Catálogo Léxico (Edge Storage).............29_**|
|**_2.6.2. Amazon S3 (Caché de resultados y almacenamiento temporal)........ 29_**|
|**_Figura 5..............................................................................................30_**|
|**_Flujograma del algoritmo de caché semántica con S3.....................30_**|
|**2.7. Pruebas de software.....................................................................................30**|
|**_2.7.1. Pruebas unitarias.................................................................................30_**|
|**_2.7.2. Pruebas de integración........................................................................ 31_**|
|**_2.7.3. Pruebas de validación técnica del backend.........................................31_**|
|**_2.7.4. Pruebas de interfaz de usuario............................................................31_**|
|**_2.7.5. Pruebas funcionales y de aceptación del usuario...............................31_**|
|**2.8. Procesamiento de Lenguaje Natural aplicado a la traducción de glosas32**|
|**2.9. Síntesis de voz y accesibilidad auditiva......................................................32**|
|**2.10. Comunicación cliente-servidor y servicios en la nube............................33**|
|**2.11. Seguridad, privacidad y manejo de la información sensible..................33**|
|**3. MARCO METODOLÓGICO............................................................................. 35**|
|**3.1. Adaptación de la metodología.....................................................................35**|
|**Figura 6..............................................................................................35**|
|**Tablero Kanban del proyecto OpenSoul.........................................35**|
|**3.2. Gestión del tablero Kanban en Trello........................................................ 36**|
|**3.3. Organización de tareas por épicas..............................................................36**|
|**3.4. Priorización y criterios de finalización...................................................... 36**|
|**3.5. Seguimiento y control del avance............................................................... 37**|
|**3.6. Trazabilidad técnica del desarrollo............................................................ 37**|
|**3.7. Cronograma e hitos del desarrollo............................................................. 37**|



|**Tabla 7................................................................................................38**|
|---|
|**Hitos del desarrollo (10 marzo - 17 junio)...................................... 38**|
|**4. INGENIERÍA DEL PROYECTO.......................................................................39**|
|**4.1. Diseño de la arquitectura  de software.......................................................39**|
|**_4.1.1. Arquitectura de Sistemas (Cloud & Serverless)..................................39_**|
|**_Figura 7..............................................................................................39_**|
|**_Arquitectura serverless del módulo lsb_to_text_audio.....................39_**|
|**_4.1.2. Arquitectura de la Aplicación Móvil (Clean Architecture)................41_**|
|**_1. Diagrama de Capas y Dependencias...................................................41_**|
|**_Figura 8..............................................................................................41_**|
|**_Diagrama de capas y dependencias del módulo lsb_to_text_audio. 41_**|
|**_2. Detalle de las Capas.............................................................................42_**|
|**_3. Flujo de Ejecución (Acción: Traducir)...............................................42_**|
|**_Figura 9..............................................................................................43_**|
|**_Flujograma de ejecución de la acción "Traducir" en_**<br>**_lsb_to_text_audio............................................................................... 43_**|
|**_4.1.3. Diagrama de Casos de Uso del Sistema.............................................. 44_**|
|**_Figura 10............................................................................................45_**|
|**_Diagrama de casos de uso del módulo lsb_to_text_audio................ 45_**|
|**_4.1.4. Diagrama de Clases (Dominio)........................................................... 45_**|
|**_Figura 11............................................................................................ 46_**|
|**_Diagrama de clases del dominio del módulo lsb_to_text_audio...... 46_**|
|**_4.1.5. Diagrama de Flujo de Datos (Secuencia de Traducción).................. 46_**|
|**_Figura 12............................................................................................47_**|
|**_Diagrama de flujo de datos de la secuencia de traducción.............. 47_**|
|**_4.1.6. Patrones de Diseño Aplicados............................................................. 47_**|
|**4.2. Implementación del módulo lsb_to_text_audio.........................................48**|
|**_4.2.1. Flujo de entrada mediante tarjetas glosa............................................48_**|
|**_4.2.2. Construcción del relato y selección semántica................................... 49_**|
|**_4.2.3. Envío al backend y procesamiento remoto..........................................50_**|
|**_4.2.4. Generación de texto formal................................................................. 50_**|
|**_4.2.5. Generación y reproducción de audio.................................................. 51_**|
|**_Figura 13............................................................................................52_**|
|**_Diagrama Técnico del Flujo de Implementación.............................52_**|
|**4.3. Integración con AWS...................................................................................52**|
|**_4.3.1. Configuración de API Gateway...........................................................52_**|
|**_4.3.2. Despliegue y ejecución de Lambda..................................................... 53_**|
|**_4.3.3. Refinamiento con Bedrock.................................................................. 53_**|
|**_4.3.4. Síntesis de audio con Polly.................................................................. 54_**|
|**_4.3.5. Almacenamiento temporal en S3.........................................................54_**|



|**_4.3.6. Estrategia de caché con S3..................................................................54_**|
|---|
|**_Figura 14............................................................................................55_**|
|**_Diagrama de Integración AWS..........................................................55_**|
|**4.4. Validación técnica........................................................................................ 55**|
|**_4.4.1. Validación funcional............................................................................55_**|
|**_Tabla 2................................................................................................ 56_**|
|**_Matriz de pruebas automatizadas del módulo lsb_to_text_audio.... 56_**|
|**_4.4.2. Validación semántica........................................................................... 57_**|
|**_Tabla 3................................................................................................ 58_**|
|**_Cobertura semántica del motor por contexto (322 casos)................ 58_**|
|**_Tabla 4................................................................................................ 59_**|
|**_Ejemplos de traducción glosa LSB - español formal........................59_**|
|**_4.4.3. Validación de experiencia de usuario..................................................59_**|
|**_Figura 15............................................................................................60_**|
|**_Diagrama de Validación técnica lsb_to_text_audio..........................60_**|
|**_4.4.4. Validación cuantitativa de la compuerta híbrida................................60_**|
|**_Tabla 5................................................................................................ 61_**|
|**_Desempeño del detector de degeneración del backend.....................61_**|
|**5. CONCLUSIONES Y RECOMENDACIONES..................................................61**|
|**7. BIBLIOGRAFÍA...................................................................................................62**|
|**ANEXOS....................................................................................................................65**|
|**ANEXO A................................................................................................ 65**|
|**ANEXO B................................................................................................ 66**|
|**ANEXO C................................................................................................ 67**|
|**ANEXO D................................................................................................ 70**|
|**ANEXO E................................................................................................ 71**|
|**ANEXO F.................................................................................................74**|



### **INTRODUCCIÓN** 

### **1. MARCO CONTEXTUAL** 

### **1.1. Antecedentes** 

### **1.1.1. Antecedentes Nacionales** 

En Bolivia, la atención educativa y social dirigida a personas con discapacidad auditiva se desarrolla bajo un enfoque inclusivo que reconoce la Lengua de Señas Boliviana (LSB) como lengua natural de la comunidad sorda. La Constitución Política del Estado establece el principio de igualdad de oportunidades y la no discriminación, incluyendo a las personas con discapacidad dentro de los grupos que deben recibir protección especial por parte del Estado [1]. En concordancia con ello, la Ley N° 223 determina que el Estado debe garantizar accesibilidad en los servicios públicos y el acceso a la información y comunicación en condiciones de igualdad [2]. Asimismo, la Ley N° 977 reconoce oficialmente la Lengua de Señas Boliviana como lengua natural de las personas sordas en Bolivia, promoviendo su uso y difusión en instituciones públicas y privadas [3]. En el ámbito educativo, diversas instituciones aplican el modelo bilingüe–bicultural, donde la LSB constituye la primera lengua y el español escrito se aborda como segunda lengua [4]. La Unidad Educativa de Audiología “Lucy Argandoña – Fe y Alegría”, ubicada en la ciudad de Cochabamba, es una institución que brinda educación formal a niños y jóvenes con discapacidad auditiva bajo este modelo [4]. En esta institución, la enseñanza y la interacción académica se desarrollan principalmente en LSB, mientras que el español escrito se incorpora como herramienta complementaria para la alfabetización y la interacción con el entorno oyente. 

Mediante una entrevista realizada a un tutor académico del nivel secundario (Anexo A), se identificaron las prácticas comunicacionales que los estudiantes emplean en su vida cotidiana. Según el relato del tutor, los jóvenes sordos, al interactuar entre sí, priorizan el uso de videollamadas a través de aplicaciones móviles debido a que la comunicación visual les permite expresarse con mayor fluidez y rapidez en LSB, en contraste con la escritura de texto, que les resulta más lenta y menos precisa. Esta dinámica evidencia que la comunicación natural de los estudiantes se produce en modalidad viso-gestual, 

mientras que la escritura en español representa un proceso adicional de traducción lingüística. El tutor también describió el procedimiento que los estudiantes o sus familias deben seguir cuando requieren realizar un trámite o interponer una denuncia en entidades públicas, tales como dependencias de la Policía Boliviana o instancias de la Defensoría del Pueblo [5, 6]. 

De acuerdo con la información recopilada, el estudiante o su familiar, al necesitar interponer una denuncia o realizar una consulta legal, debe comunicarse inicialmente con un intérprete de LSB, cuya disponibilidad es limitada y generalmente requiere coordinación previa. En ausencia de un intérprete, el estudiante debe acudir acompañado de un familiar oyente que pueda mediar la comunicación. Una vez en la entidad correspondiente, el funcionario público intenta comprender la situación mediante preguntas escritas en español, a las cuales la persona sorda responde también por escrito, generándose un intercambio de notas que se extiende durante todo el proceso de toma de declaración o denuncia (Anexo B). En situaciones de emergencia o fuera del horario de disponibilidad de un intérprete, las personas sordas recurren a escribir en trozos de papel, proceso que implica mayor tiempo de interacción y requiere adaptación al español escrito como segunda lengua. 

A nivel organizativo, la representación de la comunidad sorda en Bolivia se articula a través de la Federación Boliviana de Sordos (FEBOS), entidad que agrupa asociaciones departamentales y promueve la difusión y defensa de la LSB como elemento central de identidad lingüística y cultural [7]. Las asociaciones departamentales, como la Asociación de Sordos de Cochabamba, participan en actividades de capacitación, sensibilización y coordinación de servicios de interpretación cuando son requeridos por instituciones públicas [7]. En el ámbito tecnológico nacional, las iniciativas vinculadas a la Lengua de Señas Boliviana (LSB) se han desarrollado principalmente en el área educativa, documental y de formalización lingüística digital. Diversos proyectos académicos han abordado la representación computacional de la LSB desde una perspectiva estructural. Investigadores de la Universidad Privada Boliviana desarrollaron un lenguaje formal de descripción para la LSB junto con un compilador asociado, el cual permite modelar señas mediante parámetros estructurados que representan configuraciones manuales, movimientos y transiciones temporales. Este trabajo propone 

un sistema formal que facilita la generación de animaciones digitales de señas y constituye una base para el desarrollo de aplicaciones tecnológicas relacionadas con la representación digital de la lengua [8]. En el ámbito de innovación estudiantil, estudiantes de la Universidad Franz Tamayo desarrollaron el videojuego educativo Slite, una aplicación interactiva orientada al aprendizaje del alfabeto dactilológico y vocabulario básico de la LSB mediante reconocimiento de gestos con cámara. La herramienta utiliza procesamiento de imagen para identificar configuraciones manuales y compararlas con patrones almacenados en el sistema, proporcionando retroalimentación al usuario con fines pedagógicos [9].Por otro lado, en la Universidad Católica Boliviana (UCB) San Pablo, regional Cochabamba, se han registrado avances significativos en el desarrollo de herramientas de asistencia para la LSB. En una fase inicial (2020), se diseñó un prototipo de aplicación móvil orientado a la traducción de audio a lengua de señas utilizando el motor Unity; aunque su alcance fue acotado a un vocabulario de 50 señas y dependía del deletreo dactilológico para palabras no registradas [19]. Esta iniciativa fue evolucionada en 2021, logrando expandir el léxico a 500 palabras e incorporando reglas de tiempos verbales. Sin embargo, este sistema mantenía una estructura de animaciones pre-renderizadas de palabras aisladas, lo que limitaba la fluidez necesaria para la construcción de mensajes complejos o diálogos dinámicos en tiempo real [20]. Asimismo, en el contexto de programas de innovación tecnológica escolar impulsados por la iniciativa Solve for Tomorrow, se presentó el proyecto boliviano denominado “Traductor de Lengua de Señas con Inteligencia Artificial”, desarrollado por estudiantes de nivel secundario en el marco de competencias de innovación tecnológica educativa. Este prototipo consistió en un sistema capaz de capturar imágenes de configuraciones manuales mediante una cámara convencional, procesarlas a través de algoritmos de visión computacional para la detección y segmentación de la mano, y posteriormente clasificarlas utilizando modelos básicos de aprendizaje automático entrenados con un conjunto limitado de señas previamente registradas. El sistema realizaba la correspondencia entre la seña identificada y su equivalente léxico en español escrito, mostrando el resultado en pantalla en tiempo real [10]. 

En el entorno digital también se encuentran diccionarios en línea y repositorios multimedia que incorporan entradas correspondientes a la Lengua de Señas Boliviana, 

permitiendo la consulta de vocabulario mediante representaciones visuales en video o animación, contribuyendo a la documentación y difusión lingüística . En consecuencia, el contexto tecnológico nacional en relación con la LSB se caracteriza por el desarrollo de herramientas educativas interactivas, propuestas de formalización computacional de la lengua, recursos digitales audiovisuales y prototipos académicos orientados al reconocimiento de señas y aprendizaje de vocabulario. Estos antecedentes evidencian un escenario donde la tecnología se ha incorporado progresivamente como apoyo al aprendizaje, documentación y representación digital de la Lengua de Señas Boliviana dentro del marco educativo e institucional del país. 

### **1.1.2. Antecedentes Internacionales** 

A nivel internacional, el desarrollo de tecnologías aplicadas a las lenguas de señas ha evolucionado significativamente en las últimas dos décadas, incorporando avances en visión computacional, inteligencia artificial, aprendizaje profundo, procesamiento de lenguaje natural y síntesis de voz. Estas investigaciones y desarrollos tecnológicos han buscado abordar la comunicación multimodal entre personas sordas y oyentes mediante sistemas de reconocimiento, traducción y representación digital de distintas lenguas de señas, considerando que cada país posee una lengua de señas propia con estructura gramatical independiente de la lengua oral dominante. 

Uno de los proyectos internacionales más consolidados en el ámbito documental y educativo es Spreadthesign, una plataforma multilingüe que funciona como diccionario digital de lenguas de señas y que incluye más de 40 lenguas de señas diferentes [11]. Esta herramienta proporciona videos demostrativos de cada seña, categorización por temas y equivalencias léxicas entre distintas lenguas. Su arquitectura se basa en una base de datos audiovisual estructurada que permite la consulta por palabra clave, idioma o categoría semántica. Spreadthesign ha sido utilizado tanto con fines educativos como de documentación lingüística, contribuyendo a la estandarización y difusión internacional de vocabulario en diversas lenguas de señas. 

En el ámbito del reconocimiento automático de señas, investigaciones desarrolladas en la Florida Atlantic University presentaron un sistema basado en aprendizaje profundo para la identificación de gestos correspondientes a la American Sign Language (ASL) [12]. Este sistema utiliza redes neuronales convolucionales (CNN) entrenadas con bases de datos de imágenes y secuencias de video etiquetadas, combinadas con algoritmos de 

detección de puntos clave (keypoints) para identificar posiciones articulares de manos y dedos. El modelo implementado logra clasificar configuraciones manuales estáticas y dinámicas con alta precisión, integrando módulos de seguimiento temporal que permiten reconocer secuencias continuas de señas en tiempo real. 

Complementariamente, investigaciones publicadas en el European Journal of Artificial Intelligence & Machine Learning describen un sistema de reconocimiento de lengua de señas basado en visión computacional desarrollado en Bangladesh [13]. Este sistema fue diseñado para interpretar gestos correspondientes a la Bangla Sign Language mediante una arquitectura compuesta por módulos de captura de imagen, preprocesamiento, extracción de características y clasificación automática. En la fase de preprocesamiento se aplica segmentación de imagen para aislar la región de interés (mano) del fondo, utilizando técnicas de detección de contornos y umbralización adaptativa. Posteriormente, el sistema extrae características geométricas y espaciales como orientación, ángulos articulares y distribución de píxeles relevantes, que son utilizadas como vectores de entrada para algoritmos de aprendizaje supervisado, incluyendo Support Vector Machines (SVM) y redes neuronales multicapa. El modelo fue entrenado con un conjunto de datos previamente etiquetado y validado experimentalmente, alcanzando niveles de precisión significativos en la clasificación de señas individuales. El resultado del proceso consiste en la conversión automática de la seña detectada en texto escrito en pantalla, orientado a facilitar la comunicación básica entre personas sordas y oyentes en contextos cotidianos. 

En el ámbito de dispositivos portátiles (wearables), investigadores de la Universidad de California, Los Ángeles (UCLA) desarrollaron un sistema basado en un guante inteligente equipado con sensores extensibles capaces de medir flexión, presión y movimiento tridimensional de los dedos [14]. El dispositivo incorpora sensores piezorresistivos y acelerómetros distribuidos a lo largo de la estructura del guante, permitiendo capturar datos cinemáticos precisos asociados a cada configuración manual. Estos datos son transmitidos en tiempo real a una aplicación móvil donde un modelo de aprendizaje automático previamente entrenado procesa las señales numéricas para identificar la seña correspondiente. Una vez clasificada, la aplicación convierte automáticamente el resultado en voz sintética mediante un módulo de síntesis de habla ( _Text-to-Speech_ ), generando audio comprensible para interlocutores oyentes. Este sistema 

integra hardware flexible, procesamiento de señales y algoritmos de clasificación, constituyendo un antecedente relevante en la traducción directa de lengua de señas a voz digitalizada. 

En Europa, el sistema SignAll representa uno de los avances más integrales en traducción automática entre lengua de señas y texto [15]. Este sistema utiliza múltiples cámaras para capturar movimientos corporales completos y aplica modelos de procesamiento de lenguaje natural para interpretar la estructura gramatical de la ASL. A diferencia de sistemas que reconocen solo palabras aisladas, SignAll está diseñado para procesar frases completas, incorporando análisis sintáctico y contextualización semántica. El sistema también permite la traducción inversa, es decir, de texto escrito a representación visual en lengua de señas mediante animaciones estructuradas. 

En la India, investigadores de la Punjabi University desarrollaron un sistema de conversión de lenguaje hablado a Indian Sign Language (ISL) mediante el uso del sistema de notación HamNoSys (Hamburg Notation System) y su representación en SiGML (Signing Gesture Markup Language) [16]. Este modelo convierte texto reconocido por sistemas de reconocimiento de voz en notación estructurada, que posteriormente es transformada en animaciones 3D de un avatar digital que ejecuta las señas correspondientes. Este enfoque destaca por su formalización lingüística intermedia antes de la representación visual. 

En América Latina, un proyecto desarrollado en la Universidad Estatal de Milagro (Ecuador) implementó un traductor experimental de lengua de señas ecuatoriana utilizando sensores giroscópicos y acelerómetros integrados en dispositivos portátiles [17]. El sistema captura movimientos de la mano, procesa los datos mediante microcontroladores y realiza la correspondencia con palabras predefinidas en una base de datos, mostrando el resultado en texto. 

Por otro lado, investigaciones recientes publicadas en plataformas como arXiv describen modelos de reconocimiento continuo de lengua de señas basados en arquitecturas Transformer y redes neuronales recurrentes (RNN) [18]. Estos modelos procesan secuencias temporales de video completo, capturando información de manos, rostro y postura corporal mediante herramientas como MediaPipe Holistic y OpenPose, lo que 

permite una interpretación más precisa de la estructura lingüística y expresiones no manuales asociadas a la lengua de señas. 

En conjunto, estos antecedentes internacionales evidencian múltiples enfoques tecnológicos aplicados a diversas lenguas de señas  American Sign Language (Estados Unidos), Indian Sign Language (India) y latinoamericanas cada una con particularidades gramaticales y estructurales propias. Los desarrollos abarcan desde diccionarios digitales y sistemas educativos interactivos hasta modelos avanzados de traducción automática multimodal que integran reconocimiento visual, procesamiento lingüístico y síntesis de voz, consolidando un panorama global de investigación y aplicación tecnológica en el ámbito de la accesibilidad comunicativa. 

En el ámbito del procesamiento de lenguaje natural, diversos estudios han aplicado modelos de inteligencia artificial para la interpretación semántica, clasificación de intención y generación automática de texto en contextos especializados. Estos enfoques permiten transformar secuencias estructuradas de entrada en representaciones lingüísticas formales, constituyendo un fundamento conceptual para el desarrollo de sistemas inteligentes orientados a la estructuración automática de declaraciones en contextos jurídicos. 

**Tabla 1** 

_Tabla de análisis de sistemas similares disponibles a nivel global y local_ 

|Sistema|Incluye<br>LSB|Reconocim<br>iento<br>automático<br>de señas|Traducci<br>ón a<br>texto|Traducció<br>n texto<br>señas|Uso de<br>IA /_Deep_<br>_Learning_|Generaci<br>ón de<br>audio<br>(TTS)|Procesam<br>iento de<br>frases<br>completa<br>s|
|---|---|---|---|---|---|---|---|
|Spreadth<br>esign|X|X|✓|✓|X|X|X|
|Sistema<br>ASL –<br>Florida<br>Atlantic<br>Universit<br>y|X|✓|✓|X|✓|X|✓|
|Sistema|X|✓|✓|X|✓|X|X|



|ML –<br>Banglade<br>sh||||||||
|---|---|---|---|---|---|---|---|
|Guante<br>Inteligen<br>te –<br>UCLA|X|✓|✓|X|✓|✓|X|
|SignAll|X|✓|✓|✓|✓|X|✓|
|Sistema<br>HamNoS<br>ys +<br>SiGML –<br>India|X|X|X|✓|X|X|✓|
|Traducto<br>r<br>Ecuador<br>–<br>UNEMI|X|✓|✓|X|X|X|X|
|Valverde<br>/<br>Camacho<br>(UCB)<br>[19, 20]|✓|X|✓|✓|X|X|X|



Fuente: Elaboración propia basada en base a [11, 12, 13, 14, 15, 16, 17, 18, 19, 20], 2025. 

### **1.2. Problema** 

### **1.2.1. Situación problemática** 

- La dependencia exclusiva de mecanismos textuales no especializados en la estructura gramatical de la LSB en los procesos de atención judicial impide la construcción estructurada de declaraciones en tiempo real, derivando en registros incompletos y mal interpretados por parte de los operadores de justicia. 

- La adaptación lingüística forzada al español escrito en los procedimientos administrativos y de asesoría en entornos judiciales distorsiona la precisión de los relatos de los usuarios sordos. 

- La arquitectura de los diccionarios digitales actuales, basada en la consulta independiente de unidades léxicas de la LSB, limita la traducción y construcción de declaraciones completas o mensajes continuos en tiempo real. 

- La coordinación previa requerida para acceder a intérpretes de LSB en trámites formales restringe la inmediatez comunicativa en situaciones administrativas o de emergencia. 

- Los modelos académicos actuales de formalización de la LSB, restringen la estructuración de mensajes continuos en interacciones ciudadanas reales. 

### **1.2.2. Formulación del problema** 

La dependencia de intérpretes presenciales de disponibilidad limitada y la adaptación comunicativa forzada al español escrito aplicadas en el proceso de traducción de LSB a texto/audio en entornos judiciales, provocan la distorsión de los relatos, pérdida de inmediatez comunicativa y dificultades de comprensión en los operadores de justicia. 

### **1.3. Objetivos** 

### **1.3.1. Objetivo general** 

Desarrollar una aplicación móvil basada en un sistema inteligente de análisis semántico para el proceso de traducción de glosas de la Lengua de Señas Boliviana (LSB) a texto formal y audio  en entornos judiciales . 

### **1.3.2. Objetivos específicos** 

- Diseñar la arquitectura del sistema de software móvil para el procesamiento y traducción de glosas LSB a texto formal y audio en entornos judiciales. 

- Desarrollar el módulo de entrada visual táctil mediante un catálogo de tarjetas digitales que representen el vocabulario y glosas LSB. 

- Implementar el módulo de procesamiento de lenguaje natural mediante una arquitectura híbrida de análisis semántico con lexicón LSB y un modelo fundacional. 

- Desarrollar el módulo de generación de salida multimodal para convertir el texto formal procesado en audio continuo mediante síntesis de voz neuronal (TTS). 

- Implementar pruebas funcionales y de coherencia semántica del sistema mediante escenarios simulados de atención y recepción de información en entornos judiciales. 

### **1.4. Alcances** 

- El corpus lingüístico-administrativo de glosas LSB estará estructurado con metadatos de contexto, prioridad y dialecto boliviano. 

- El módulo de interfaz táctil proporcionará un catálogo de tarjetas visuales organizadas por categorías, permitiendo construir su relato. 

- El motor de traducción integrará una arquitectura híbrida de análisis semántico con lexicón LSB y un modelo fundacional para generar oraciones con coherencia gramatical. 

- El módulo de salida multimodal utilizará síntesis de voz neuronal para transformar el texto generado en audio. 

- Se ejecutarán pruebas funcionales con escenarios simulados en entornos judiciales, validando la coherencia semántica entre las glosas seleccionadas y el texto generado. 

### **1.5. Límites** 

- El corpus estará restringido al dialecto LSB de la región de Cochabamba, sin garantizar compatibilidad con variaciones lingüísticas de otros departamentos. 

- El sistema utilizará exclusivamente tarjetas digitales táctiles como entrada, excluyendo el reconocimiento automático de señas por cámara (Computer Vision). 

- El sistema empleará modelos de lenguaje pre-entrenados mediante _APIs_ ( _Application Programming Interface_ )  y síntesis de voz neuronal en español latinoamericano, excluyendo entrenamiento desde cero y otros motores o lenguas alternativos. 

- El proyecto se limitará al desarrollo del software móvil, excluyendo la provisión de dispositivos. 

- Las pruebas se realizarán en entornos académicos simulados, excluyendo validación oficial en trámites o procesos reales vinculantes. 

### **1.6. Justificación** 

- La construcción del corpus lingüístico-administrativo de glosas LSB proporcionará la inmediatez comunicativa en situaciones administrativas o de emergencia. 

- La arquitectura híbrida de procesamiento de lenguaje natural, compuesta por un motor semántico propio y un modelo fundacional Transformer, permitirá construir declaraciones completas y gramaticalmente coherentes a partir de glosas LSB aisladas. 

- La síntesis de voz neuronal permitirá reproducir las declaraciones en formato auditivo continuo, facilitando la comunicación directa entre la persona sorda y el operador de justicia o funcionario judicial sin intermediarios humanos. 

- La ejecución de pruebas funcionales en escenarios simulados permitirá verificar la coherencia semántica del sistema antes de su aplicación en entornos judiciales, garantizando la precisión de las declaraciones generadas. 

### **2. MARCO TEÓRICO** 

El presente capítulo constituye la base conceptual y técnica indispensable para el sustento del desarrollo de la aplicación móvil OpenSoul. En este apartado se exponen las teorías, paradigmas y herramientas tecnológicas que fundamentan la creación del módulo _lsb_to_text_audio_ , capaz de transformar la Lengua de Señas Boliviana (LSB) expresada mediante la selección de glosas en texto formal en español y audio reproducible, asegurando que la solución posea el rigor técnico requerido por la Ingeniería de Sistemas. 

### **2.1. Lengua de Señas Boliviana(LSB)** 

Para el desarrollo de una herramienta tecnológica de traducción resulta imperativo establecer que la Lengua de Señas Boliviana (LSB) no consiste en una mera representación manual o mímica del idioma español. Se trata de un idioma natural, independiente y con una estructura lingüística propia, reconocida oficialmente como lengua materna de la comunidad sorda en Bolivia mediante la promulgación de la Ley N° 1658 en 1995 [13]. El reconocimiento de su estatus lingüístico determina que cualquier sistema de traducción automatizado debe procesarla bajo los mismos estándares de complejidad que una lengua oral. 

### **2.1.1. Naturaleza viso-gestual** 

Las lenguas orales, como el español, fundamentan su comunicación en un canal auditivo-vocal, caracterizándose por una linealidad temporal estricta; es decir, se pronuncia una palabra después de otra. Por el contrario, la LSB es una lengua de naturaleza viso-gestual y espacial. La información lingüística no se emite linealmente, sino de manera tridimensional y simultánea, utilizando el espacio físico que rodea al emisor [18]. 

En el módulo lsb_to_text_audio, esta naturaleza viso-gestual condiciona el diseño de la entrada: la persona sorda no escribe en español —segunda lengua para la mayoría— sino que construye su relato seleccionando tarjetas visuales de glosas ( _LsbCard_ ) organizadas por categorías semánticas. Cada tarjeta se acompaña de un ícono semántico de Material Icons que refuerza visualmente el concepto, garantizando que el usuario componga su declaración en su lengua natural sin pasar por la escritura. 



<!-- Start of picture text -->
LOS SEIS PARAMETROS FORMACIONALES DE UNA SENA (LSB) I<br>1. CONFIGURACION MANUAL Wy! 4. MOVIMIENTO<br>AIT: ae<br>Forma V0) eo<br>Ej. especifica de la mano. | Teco 3a eee<br>.  Mano en copa para “GRACIAS", ( j 4: sagas acia afuera<br>qj», = GRACIAS lesde la Darbilla.<br>ui 2- ORIENTACION —<br>Be  GtMEL on fh G- ( Wh :We 5, DIRECCION<br>D | Yi Hacia donde se dirige<br>losdedos.de|Palma| if AA mess<br>el hacia \ \ Pi ow elmovimiento,<br>cuerpo para “GRACIAS”. a aaclatte:<br>GRACIAS )<br>°suncacinba aefiolécivo. Gy ©)-> ~=—-Expresionesemanatesfaciales,<br>, P 6. COMPONENTES<br><!-- End of picture text -->

Sujeto-Verbo-Objeto (SVO), mientras que la LSB emplea frecuentemente una estructura Objeto-Sujeto-Verbo (OSV) y ubica los marcadores de tiempo al inicio de la oración para establecer primero el contexto espacial y temporal (por ejemplo: "Ayer calle ladrón celular robar") [2, 20]. 

Por esta razón, el sistema no puede realizar una traducción literal palabra por palabra. El módulo lsb_to_text_audio resuelve esta divergencia en su _backend_ : la función Lambda analiza la secuencia de glosas seleccionadas ( _analyze_glosses_ ), clasifica cada una por su rol gramatical mediante el diccionario GLOSS_LEXICON y reordena los componentes hacia una oración gramaticalmente correcta en español formal, garantizando que la declaración del usuario sordo conserve su intención original. 

### **2.1.4. Comprensión lectora del español escrito en l a comunidad sorda** 

Es un error común en la administración pública asumir que una persona sorda puede comprender a cabalidad un texto escrito en español. Para la mayoría de la comunidad sorda boliviana, debido a la dificultad de acceder al aprendizaje fonético del idioma, el español escrito se constituye como una segunda lengua, resultando a menudo en un bajo nivel de comprensión lectora [5]. 

Este factor indica la importancia crítica del proyecto en el ámbito jurídico. La simple transcripción de voz a texto en una comisaría o juzgado resulta insuficiente para garantizar el consentimiento informado, tal como lo exige el Artículo 13 de la Convención sobre los Derechos de las Personas con Discapacidad de las Naciones Unidas [10] y la Ley N° 223 [1]. El módulo lsb_to_text_audio permite superar esta barrera transformando la declaración construida en glosas LSB —lengua natural del usuario directamente a texto formal y audio comprensibles para el funcionario oyente. 

### **2.1.5 Fuentes documentales y audiovisuales del corpus léxico LSB** 

El corpus léxico utilizado en el módulo lsb_to_text_audio fue construido mediante un proceso de recopilación, selección y normalización de glosas provenientes de fuentes documentales y audiovisuales de la Lengua de Señas Boliviana. La base principal del catálogo corresponde a los módulos oficiales de enseñanza de la LSB, publicados por el Ministerio de Educación de Bolivia en coordinación con instituciones vinculadas a la comunidad sorda [21], [22], [36], [37] [38] [39]. Estos módulos permitieron identificar 

glosas de uso general relacionadas con personas, objetos, tiempo, entorno cotidiano, prendas de vestir, profesiones, colores, verbos, estados físicos, emociones y vocabulario social. 

Sin embargo, debido a que el dominio del proyecto está orientado a contextos judiciales y administrativos, algunas glosas requeridas por el sistema no se encontraban explícitamente documentadas en los módulos iniciales de aprendizaje consultados. Para cubrir esos vacíos léxicos se incorporaron fuentes audiovisuales complementarias [38] [39], principalmente videos de enseñanza, difusión o demostración de LSB, a partir de los cuales se identificaron glosas relacionadas con agresión, trámites, instituciones, objetos de denuncia y situaciones de emergencia. 

Las glosas obtenidas de fuentes audiovisuales fueron tratadas como vocabulario complementario y no como reemplazo de las fuentes documentales base. Para mantener la trazabilidad del corpus, cada glosa fue clasificada según su origen: módulo oficial, seña compuesta, dactilología, fuente audiovisual o adaptación funcional al dominio judicial. Esta clasificación permite justificar la procedencia de las 153 glosas implementadas y diferenciar entre vocabulario documentado, vocabulario compuesto y vocabulario especializado incorporado por necesidad funcional del sistema. 

### **2.2. Arquitectura del Software** 

La arquitectura de software constituye la estructura conceptual y lógica sobre la cual se diseñan y construyen los sistemas informáticos. De acuerdo con Bass, Clements y Kazman, la arquitectura comprende la definición de los componentes de software, sus propiedades externas visibles y las relaciones que existen entre ellos, garantizando atributos de calidad como escalabilidad, mantenibilidad, testabilidad y rendimiento [23]. 

Para el desarrollo del módulo lsb_to_text_audio se ha adoptado el patrón Arquitectura Limpia ( _Clean Architecture)_ , propuesto por Robert C. Martin [24, 25]. Este patrón se fundamenta en la "Separación de Responsabilidades" y en la Regla de Dependencia, que establece que las dependencias del código fuente siempre deben apuntar hacia el interior del sistema. Las capas internas, que contienen las reglas de negocio, no conocen nada 



<!-- Start of picture text -->
Gare fA PRESENTACION(Essay) © INTERIACA»+ WebAPI  Controllers USUARIO<br>ae DATOS fal « View Adapters<br>= (Medio) =s<br>‘<br>= Use/Cadios a © DATA+ Data DE Sources ACCESS<br>« Repositories<br>ARQUITECTURASONDIAGRAMAUPCION ESTRUCTRIO LIMPIA DE ea DOMINIO(Interior) 58 8 » Gateways<br>° =<br>(CLEAN ARCHITECTURE) o\-S [Brislige. oy o DOMINIO* Businesis Rueles(interior)<br>« Use Cases<br>ee<br>QStcig *« DominioEntidadesLogic<br>pueLas de pendenciasn apuntar hacia de céa d entro.igo solo — p><br><!-- End of picture text -->

- **Servicios de Dominio:** _SemanticNavigationEngine_ (motor que prioriza las zonas semánticas según las glosas elegidas) y _LocalSentenceAssembler_ (motor propio que arma una oración base en español como respaldo sin conexión). 

- **Contratos de Repositorios:** interfaces abstractas como _CardsRepository_ y _TranslationRepository_ , que dictan qué acciones pueden realizarse sin importar cómo se realicen técnicamente. 

### **2.2.2. Capa de Datos (Data Layer)** 

Es la capa encargada de gestionar, persistir y proveer la información que el sistema requiere de fuentes ajenas a él. Implementa los contratos que la capa de dominio ha definido previamente, orquestando el acceso a datos locales y a servicios web mediante los denominados _DataSources_ [25]. Esta capa alberga _LocalCardsDataSource_ , que mantiene en memoria el catálogo léxico de tarjetas LSB, y _RemoteTranslationDataSource_ , cuya responsabilidad es serializar las glosas en formato JSON, ejecutar una petición HTTP asíncrona hacia la API Gateway de AWS, gestionar los códigos de respuesta (HTTP 200 de éxito o errores) y mapear el JSON recibido a la entidad TranslationResult. 

### **2.2.3. Capa de Presentación (Presentation Layer)** 

Constituye el anillo más externo del patrón y es responsable de la interacción visual con el usuario. Abarca el diseño de la interfaz móvil y los componentes de visualización. En el módulo _lsb_to_text_audio_ esta capa incluye la pantalla _HomeScreen_ , el catálogo visual _CardGrid_ , la barra de zonas semánticas _SemanticZonesBar_ y el constructor de oraciones _SentenceBuilder_ . Para orquestar estos elementos sin penalizar el rendimiento se utiliza el controlador reactivo _TranslationController_ , gobernado por Riverpod, que cambia de manera limpia entre los estados de "cargando", "éxito" o "error", actualizando la pantalla sin bloquear el hilo principal de renderizado del dispositivo móvil. 

### **2.3. Metodología de desarrollo de Software** 

Para la gestión y ejecución técnica del proyecto OpenSoul se ha seleccionado la metodología Kanban, debido a que permite visualizar el trabajo, limitar el trabajo en curso y gestionar el flujo de entrega de forma continua. Esta elección se adapta al 

desarrollo de un proyecto de grado con tareas técnicas, validaciones iterativas y necesidad de trazabilidad sobre cada actividad implementada. 

### **2.3.1. Visualización del flujo: Tablero Kanban** 

Las tareas del proyecto se administran en un tablero Kanban implementado en Trello, donde cada tarjeta representa una actividad concreta del módulo lsb_to_text_audio. El tablero se organiza en las columnas Backlog, To Do, Doing, Testing y Done, lo que permite identificar rápidamente el estado de cada tarea, los bloqueos existentes y el avance general del proyecto. 

Cada tarjeta incluye información mínima estandarizada, como el nombre de la tarea, descripción, épica funcional, prioridad, esfuerzo estimado, dependencias técnicas, criterios de aceptación y pruebas sugeridas. Esta estructura convierte al tablero en una herramienta de control técnico y académico, no solo en un registro visual. 

### **2.3.2. Limitación del Trabajo en Curso (WIP)** 

Se restringe la cantidad de tareas simultáneas para evitar la dispersión del esfuerzo y asegurar que las actividades críticas reciban atención oportuna. Esta limitación del trabajo en curso permite concentrarse en resolver primero los riesgos técnicos más altos, como la integración con AWS, la lógica de traducción híbrida, la salida de audio y las pruebas de validación. 

### **2.3.3. Gestión del Flujo** 

Al ser un proyecto de investigación y desarrollo, Kanban permite ajustar la lógica del motor híbrido de traducción, la estructura del documento académico y el avance de implementación sin la rigidez de ciclos cerrados. La gestión del flujo facilita que las tareas se prioricen según su impacto, su dependencia técnica y su relevancia para la defensa del proyecto. 

### **2.4. Tecnologías de desarrollo de** **_Backend_** 

El _backend_ de la aplicación OpenSoul ha sido diseñado bajo un paradigma de Arquitectura _Serverless_ o sin servidor utilizando el ecosistema de Amazon Web Services 

#### Arquitectura serverless del mdédulo Isb_to_text_audio 



<!-- Start of picture text -->
3. Refinado de oraciones<br>(Bedrock API)<br>Amazon Bedrock<br>(Generative Al)<br>< 1 ahseleccionadasde ae .A 2. leglosas de 4. Solicitud dePolly sintesisAPI  de voz =<br>3 —<br>Cliente: API Gatewa Recepcién de audio MP3<br>Aplicacion (AWS) i AWS Comix P 7 Amazon Polly<br>Flutter 6. Retorno de texto yaudio | —<<br>5.consulta Almacenamientode caché y SH<br>(Audio MP8 y Respuestas) Amazon S3<br>(Almacenamiento de<br>objetos)<br><!-- End of picture text -->

### **2.4.2. AWS Lambda (Función como Servicio - FaaS)** 

AWS Lambda es el servicio de cómputo orientado a eventos utilizado como núcleo orquestador del _backend_ del módulo lsb_to_text_audio. Su función consiste en recibir las glosas seleccionadas desde la aplicación móvil, ejecutar el análisis semántico propio mediante el diccionario GLOSS_LEXICON, construir una oración base en español formal, aplicar un refinamiento opcional mediante un modelo fundacional y devolver una respuesta estructurada en formato JSON. 

La implementación actual utiliza Python como lenguaje de ejecución y resuelve también la lógica de caché, la validación de entrada, la generación de la respuesta semántica intermedia, la creación del audio y la preparación de la URL prefirmada para consumo temporal desde la aplicación. 

### **2.4.3. Amazon Bedrock (Modelos Fundacionales y PLN)** 

Amazon Bedrock se utiliza como una capa complementaria de refinamiento lingüístico. En el módulo lsb_to_text_audio no genera la traducción desde cero, sino que recibe la oración base ya construida por el propio motor y la mejora en términos de fluidez, cohesión y redacción formal, sin modificar el significado original ni introducir contenido nuevo. 

En la implementación actual, el _backend_ utiliza un modelo fundacional configurado para refinamiento del texto, actualmente Amazon Nova 2 Lite, con reglas explícitas para evitar alucinaciones y preservar la intención semántica de la declaración generada. Si el refinamiento no resulta confiable, el sistema conserva la oración base producida por reglas internas. 

### **2.4.4. Amazon Polly (Síntesis de Voz - Salida Auditiva)** 

Amazon Polly es el servicio de síntesis de voz neuronal utilizado para convertir el texto formal generado por el _backend_ en audio MP3. Esta salida auditiva permite que la declaración sea leída en voz alta para el funcionario oyente, fortaleciendo la accesibilidad comunicativa en contextos institucionales. 

La voz configurada en el proyecto corresponde a una variante en español latinoamericano, y el audio generado se entrega a la aplicación mediante una URL temporal de acceso seguro. 

### **2.4.5. Amazon S3 (Almacenamiento de Objetos y Privacidad)** 

Amazon S3 se utiliza como repositorio de almacenamiento para los audios generados y para la caché de respuestas semánticas. Los archivos MP3 se almacenan en un _bucket_ privado, y el acceso se realiza mediante URL prefirmada con tiempo limitado, con el fin de proteger la privacidad de la información generada por el usuario. 

Además, el _backend_ utiliza S3 para conservar respuestas ya procesadas y reducir el costo de futuras solicitudes idénticas, devolviendo `cacheHit = true` cuando la combinación de contexto y glosas ya ha sido resuelta anteriormente. 

### **2.5. Tecnologías de desarrollo de** **_Frontend_** 

El módulo de interfaz de usuario constituye el punto de contacto directo entre el software y la persona sorda en un entorno judicial crítico. Esta capa debe satisfacer tres demandas técnicas: presentar un catálogo visual de glosas comprensible y accesible, enviar la secuencia seleccionada al _backend_ de IA en AWS y reproducir el audio resultante de forma fluida. Para ello se ha seleccionado un ecosistema centrado en el rendimiento, la reactividad del estado y la mantenibilidad del código. 

### **2.5.1. Framework de desarrollo: Flutter** 

Flutter es un kit de desarrollo de software (SDK) de código abierto creado por Google para construir aplicaciones compiladas nativamente a partir de una única base de código [29]. Su rasgo diferenciador reside en su motor de renderizado propietario (Impeller), que dibuja directamente sobre la GPU del dispositivo garantizando una consistencia visual perfecta a 60 o 120 fotogramas por segundo. Flutter utiliza el lenguaje Dart, de tipado estático y con soporte nativo para la programación asíncrona mediante async/await y Streams; este soporte es la base técnica que permite que la comunicación con AWS Lambda y la reproducción de audio ocurran en hilos secundarios sin bloquear el hilo principal de renderizado. La estructura de directorios del módulo lsb_to_text_audio respeta estrictamente la separación por capas de la Arquitectura Limpia. 

Flujo de gestién de estado con Riverpod en el mdédulo Isb_to_text_audio 



<!-- Start of picture text -->
aero(StateNotifierProvider)<br>Sorin generac (ControllerTranslationController Ul: Pantallade<br>UI: Pantalla de Ae eae/ Business Logic)Ree Se ip Reactive Undale 4 Resultado<br>a a Vista de Texto<br>on - Update update Decision: Reactive Update Goniitioa dal<br>aa __... ae >is<br>eat(StateNotilierProvider)<br><!-- End of picture text -->



<!-- Start of picture text -->
—> Flow dodates<br>7 Action trigger<br><!-- End of picture text -->

_contextProvider_ (contexto situacional activo). Cuando el estado cambia, Riverpod notifica automáticamente a los widgets suscritos, que reconstruyen únicamente las partes afectadas de la pantalla sin recargar la interfaz completa. 

### **2.5.3. Síntesis y Reproducción de Audio: audio remoto y audio local** 

La salida del módulo es multimodal: además del texto formal, el sistema genera audio. Para ello se utilizan dos estrategias complementarias. Por un lado, audioplayers reproduce el audio remoto generado por Amazon Polly cuando el _backend_ responde correctamente. Por otro lado, la síntesis local funciona como respaldo mediante una abstracción independiente de salida de audio, que encapsula el uso de flutter_tts y desacopla la lógica del controlador de los plugins nativos. 

En la implementación actual, el módulo prioriza el audio remoto cuando existe una URL válida y, si esta no está disponible o falla la reproducción, activa el audio local. Esta estrategia híbrida garantiza continuidad del servicio y mantiene la salida auditiva disponible en todo momento. 

### **2.5.4. Navegación Declarativa: GoRouter** 

GoRouter se utiliza para controlar el desplazamiento entre pantallas dentro de la aplicación. En el módulo lsb_to_text_audio, esta navegación permite pasar del flujo guiado de selección de glosas a una pantalla de resultado dedicada, donde se muestra la traducción generada, el estado del audio y las acciones posteriores del usuario. 

La navegación declarativa facilita mantener el estado de la aplicación de forma ordenada y coherente con la arquitectura basada en providers. 

### **2.6. Tecnologías de DBMS** 

En las aplicaciones móviles modernas conectadas a servicios de IA en la nube, la gestión de datos no se restringe a un único motor relacional tradicional. El diseño arquitectónico contemporáneo exige un enfoque distribuido, dividiendo la persistencia en dos frentes complementarios: el almacenamiento en el borde ( _Edge Storage_ ) para respuestas de baja latencia, y el almacenamiento NoSQL en la nube ( _Cloud Storage_ ) para la escalabilidad y la optimización de costos [32]. El módulo lsb_to_text_audio adopta una estrategia de 

persistencia híbrida, empleando mecanismos de caché para minimizar los tiempos de respuesta y reducir la frecuencia de invocación de los modelos fundacionales de la IA. 

### **2.6.1. Almacenamiento Local del Catálogo Léxico (** **_Edge Storage_ )** 

En el módulo lsb_to_text_audio, el recurso crítico es el catálogo léxico de glosas LSB. La clase LocalCardsDataSource mantiene en memoria 153 tarjetas organizadas en quince categorías semánticas: Identificación, Descripción, Agresión, Armas, Acciones, Emociones, Estado/Urgencia, Objetos, Documentos, Lugares, Instituciones, Servicios, Consultas, Trámites y Tiempo. Esta estrategia permite que la persona usuaria construya su relato de forma inmediata, incluso sin conectividad de red, satisfaciendo el requisito de funcionamiento parcial sin conexión. 

### **2.6.2. Amazon S3 (Caché de resultados y almacenamiento temporal)** 

Además de servir como repositorio de audios, Amazon S3 se emplea en el proyecto como soporte de caché para respuestas ya procesadas. Esta estrategia permite almacenar la respuesta completa de una traducción previamente generada y reutilizarla cuando el usuario envía una solicitud idéntica, reduciendo la latencia y evitando ejecuciones innecesarias del _backend_ . 

En la implementación actual, la caché se organiza a partir de una clave derivada del contexto y de las glosas seleccionadas, lo que permite detectar coincidencias y responder con rapidez sin repetir el procesamiento completo. Este enfoque es coherente con la naturaleza del proyecto, ya que prioriza simplicidad de despliegue, seguridad y bajo costo de mantenimiento. 



<!-- Start of picture text -->
Flujograma del algoritmo de caché semantica con S3<br>en méddulo 'OpenSoul Isb_to_text_audio'<br>2. Consulta a .<br>&Cache Key CacheRama:Hit 3. Recuperar de DevolverResultado: JSON<br>Encontrada $3 (GET) y audioUr!<br>en $3? Preexistente<br>1. Calculo de<br>Entrada: Cache Key<br>Contexto + + Hash of input Rama: 4, Ejecutar Algoritmo Completo<br>Glosas features Cache Hit (LSB-to-Text-Audio)<br>Rama: (Calvia) en S3 (PUT)<br>Cache b Resultado:<br>Miss B. Generar Texto JSON Devolver<br>(via Bedrock) Nuevo JSON<br>(Reconstruct: sentence) S y audioUrl<br>C. Sintetizar Audio endiandio<br>(via Polly) MP3<br>(Speechdo generaci6n)<br><!-- End of picture text -->

### **2.7.3. Pruebas de validación técnica del** **_backend_** 

Se verifican la estructura de la respuesta del _backend_ , el comportamiento de la caché, la generación del texto formal, la producción del audio y la correcta interpretación de los campos devueltos por el servicio. 

### **2.7.4. Pruebas de interfaz de usuario** 

Se valida que la aplicación muestre correctamente la selección de glosas, el resultado traducido, el estado de reproducción de audio, los indicadores visuales de origen del texto y la navegación entre pantallas. 

### **2.7.5. Pruebas funcionales y de aceptación del usuario** 

Las pruebas funcionales buscan confirmar que el módulo resuelve correctamente los escenarios de uso previstos para entornos institucionales, especialmente denuncias, trámites, orientación y situaciones de emergencia. El archivo _test/full_gloss_smoke_test.dart_ ejecuta una prueba de humo exhaustiva para cada glosa del catálogo y para cada contexto oficial, permitiendo observar el comportamiento del motor local frente a categorías como identificación, descripción, agresión, acciones, emociones, estado, objetos, documentos, lugares, instituciones, servicios, consultas, trámites y tiempo. 

Estas pruebas simulan casos completos en los que la persona usuaria construye su declaración mediante glosas y luego recibe una oración formal en español. La aceptación funcional se considera satisfactoria cuando el sistema produce una oración coherente, preserva las glosas relevantes, activa el audio correspondiente y mantiene la navegación entre edición, traducción y visualización de resultados sin romper el flujo de uso. 

### **2.8. Procesamiento de Lenguaje Natural aplicado a la traducción de glosas** 

El módulo _lsb_to_text_audio_ incorpora principios de procesamiento de lenguaje natural para transformar una secuencia de glosas en una oración comprensible en español formal. Este proceso no consiste en una traducción literal palabra por palabra, sino en una reorganización semántica de la información seleccionada por la persona usuaria, respetando el orden lógico del mensaje y la intención comunicativa original. 

En la implementación del sistema, el motor local _LocalSentenceAssembler_ clasifica las glosas según su función dentro de la oración, por ejemplo sujeto, verbo, objeto, lugar, tiempo, emoción, institución o documento. A partir de esa clasificación, construye una base oracional que puede ser refinada por un modelo fundacional en el _backend_ de AWS. Esta arquitectura híbrida permite combinar reglas deterministas con capacidades generativas, reduciendo errores de interpretación y mejorando la fluidez de la salida final. Además, el _backend_ devuelve una representación intermedia con metadatos semánticos, secuencia de glosas y señales de refinamiento, lo que permite conservar trazabilidad sobre cómo se transformó la entrada original. Este enfoque resulta especialmente útil en contextos judiciales, donde la fidelidad del mensaje es más importante que una traducción libre o estilizada. 

### **2.9. Síntesis de voz y accesibilidad auditiva** 

La síntesis de voz constituye una parte central del módulo, ya que permite convertir la traducción textual en una salida auditiva accesible para funcionarios oyentes. El sistema utiliza Amazon Polly como motor principal de conversión texto a voz en el _backend_ , y complementa su funcionamiento con _flutter_tts_ como mecanismo local de respaldo cuando la URL remota no está disponible o el _backend_ no responde correctamente. 

Esta estrategia híbrida mejora la disponibilidad del servicio y asegura que el usuario siempre obtenga una salida audible. La reproducción final se realiza con _audioplayers_ cuando existe un archivo remoto generado por Polly, mientras que la síntesis local se activa para conservar continuidad operativa. De esta manera, el módulo no depende de una única fuente de audio y puede mantener la comunicación en condiciones de conectividad limitada. 

Desde el punto de vista de accesibilidad, esta funcionalidad es importante porque facilita la interacción entre una persona sorda y un interlocutor oyente en entornos donde se requiere rapidez, claridad y formalidad, como una comisaría, un juzgado o una entidad pública. 

### **2.10. Comunicación cliente-servidor y servicios en la nube** 

El módulo _lsb_to_text_audio_ se apoya en una arquitectura cliente-servidor basada en Flutter como cliente móvil y AWS como plataforma de procesamiento en la nube. La 

aplicación móvil recopila las glosas seleccionadas, las organiza según el contexto situacional y envía una solicitud HTTP POST a una API expuesta mediante Amazon API Gateway. Esta solicitud contiene información estructurada en formato JSON, lo que permite una comunicación interoperable y fácil de procesar por el _backend_ . 

Una vez recibida la petición, AWS Lambda ejecuta la lógica de traducción, consulta el motor semántico, aplica el refinamiento con Amazon Bedrock cuando corresponde, sintetiza el texto en audio mediante Amazon Polly y almacena el archivo resultante en Amazon S3. Luego, el _backend_ retorna una respuesta con la traducción generada, la URL del audio, indicadores de caché y metadatos de ejecución. 

Esta separación entre cliente y servidor aporta ventajas importantes. Por un lado, la aplicación móvil se mantiene ligera y centrada en la interacción. Por otro, el procesamiento intensivo se desplaza a la nube, permitiendo escalar el servicio y reducir la carga sobre el dispositivo del usuario. Además, el uso de una arquitectura _serverless_ favorece la elasticidad, la mantenibilidad y la reducción de costos operativos. 

### **2.11. Seguridad, privacidad y manejo de la información sensible** 

Debido a que el módulo trabaja con declaraciones, relatos personales y escenarios judiciales, la seguridad y la privacidad de la información son aspectos esenciales del diseño. La arquitectura implementada busca limitar la exposición de los datos y reducir el riesgo de acceso no autorizado durante el tránsito y almacenamiento de la información. En el _backend_ , la comunicación se realiza a través de un _endpoint_ centralizado y controlado por Amazon API Gateway, que actúa como puerta de entrada controlada para las solicitudes de la aplicación. Asimismo, el archivo de audio generado por Amazon Polly se almacena en Amazon S3 de forma privada, sin publicarlo abiertamente en internet. Para su consumo temporal, el sistema utiliza una URL prefirmada, que permite acceso restringido por un tiempo limitado. 

Adicionalmente, el sistema evita depender exclusivamente de la nube para la generación de resultados, ya que el motor local produce una oración base segura cuando el _backend_ falla o devuelve una respuesta degenerada. Este mecanismo de respaldo también contribuye a la integridad del flujo, porque evita pérdidas de información en situaciones de conectividad deficiente o de error del servicio remoto. 



<!-- Start of picture text -->
Isb_to_text_audio Kanban 0) @eaaev+=xe@<br>Backlog 4 ToDo In Progress Testing Done t + Adda<br>Caché de respuestasen A a carc Redaccion finaldel informe<br>Preparar material de defensa<br>Ampliar dataset de la<br>compuerta a 50 casos<br>Add a car<br>f Prueba de usabilidad con<br>usuarios sordos (SUS)<br>Ampliar glosas dialectales de f Add a carc<br>Cochabamba<br>del a car<br><!-- End of picture text -->

### **3.2. Gestión del tablero Kanban en Trello** 

Para materializar la metodología Kanban se utiliza un tablero digital en Trello, donde cada tarjeta representa una tarea concreta del desarrollo, una corrección técnica, una prueba o una mejora documental. El tablero se organiza en las columnas Backlog, To Do, Doing, Testing y Done, de modo que cada actividad pueda seguir su ciclo completo desde su identificación hasta su validación final. 

Cada tarjeta del tablero contiene información mínima estandarizada, como nombre de la tarea, descripción detallada, épica o área funcional, prioridad, esfuerzo estimado, dependencias técnicas, criterios de aceptación y pruebas sugeridas. Esta estructura permite que el tablero no sea solo un registro visual, sino también una herramienta de control académico y técnico. 

### **3.3. Organización de tareas por épicas** 

Las tareas del módulo lsb_to_text_audio se agrupan por épicas o áreas funcionales, con el fin de mantener orden en la planificación y permitir un seguimiento más claro del avance. Las principales épicas identificadas son: datasource remoto, AWS/ _backend_ , Riverpod y manejo de estado, pruebas, documentación, accesibilidad, deuda técnica, audio y _fallback_ , y dominio. 

Dentro de esta estructura, las tareas críticas se ubican en prioridad alta cuando afectan la estabilidad, la defensa o la coherencia del sistema. Las tareas de prioridad media se asocian con integración, validación y documentación. Las tareas de prioridad baja corresponden a refinamientos opcionales y mejoras complementarias. 

### **3.4. Priorización y criterios de finalización** 

La priorización de tareas se basa en el riesgo técnico, el impacto sobre la funcionalidad principal y la relevancia para la sustentación del proyecto. En primer lugar se atienden los problemas que pueden bloquear la ejecución del sistema o afectar directamente la traducción de glosas LSB a texto y audio. Luego se abordan las tareas de validación, pruebas y documentación, y finalmente las mejoras complementarias. 

Una tarjeta se considera terminada únicamente cuando cumple con los siguientes criterios: la funcionalidad fue implementada correctamente, el comportamiento fue verificado manualmente, las pruebas correspondientes fueron ejecutadas y superadas, la documentación asociada fue actualizada cuando aplica y no quedan bloqueos técnicos abiertos para esa tarea. 

### **3.5. Seguimiento y control del avance** 

El seguimiento del proyecto se realiza de forma periódica mediante revisión del tablero Kanban, verificación del estado de las tarjetas y análisis de los entregables completados. Este control permite observar el avance real del módulo, detectar tareas bloqueadas y reajustar la planificación cuando aparecen cambios en la integración con el _backend_ o en la estructura del documento académico. 

Adicionalmente, el uso del tablero facilita evidenciar el progreso ante el docente guía y ante el tribunal de evaluación, ya que cada ticket muestra de manera concreta qué se desarrolló, qué se validó y qué quedó pendiente. En consecuencia, la metodología no solo organiza el trabajo, sino que también respalda la trazabilidad técnica y académica del proyecto. 

### **3.6. Trazabilidad técnica del desarrollo** 

El tablero Kanban refleja directamente el trabajo realizado sobre el módulo lsb_to_text_audio. Cada tarjeta responde a una necesidad real del sistema, como corrección de errores, validación del flujo de traducción, integración con AWS, manejo de audio, pruebas automatizadas o ajuste del contrato API. De esta manera, el tablero funciona como evidencia del avance técnico y como soporte para documentar la evolución del proyecto. 

### **3.7. Cronograma e hitos del desarrollo** 

El desarrollo del módulo `lsb_to_text_audio` se llevó a cabo entre el 10 de marzo y el 9 18 de junio de 2026, bajo un flujo Kanban de entrega continua. El trabajo se organizó en 10 hitos verificables, cada uno asociado a una o más épicas del tablero y a un entregable. 

### **Tabla 2** 

_Hitos del desarrollo (10 marzo - 17 junio)_ 

|Hito|Periodo|Epicas|Entregable|
|---|---|---|---|
|Configuración del<br>proyecto y arquitectu<br>base|<br>10 - 20 marzo|Dominio,<br>Documentación|Esqueleto Clean<br>Architecture funcion|
|Integración inicial co<br>AWS y estado reacti|<br>21 - 31 marzo|AWS/Backend,<br>Riverpod|Flujo remoto básico<br>operativo|
|Reorientación del<br>dominio a servicios<br>ciudadanos|1 - 18 abril|Dominio,<br>Documentación|Catálogo y temática<br>definidos|
|Navegación semánti<br>y flujo guiado|19 abril - 25 mayo|Dominio, Riverpod|Flujo guiado por<br>contextos|
|Audio y fallback loc|23 - 31 mayo|Audio y fallback|Audio con<br>degradación<br>controlada|
|Refinamiento del<br>contrato y motor<br>semántico|1 - 14 junio|Dominio, Datasourc|Motor con cobertura<br>garantizada|
|Cobertura del lexicó<br>y coherencia de flujo|<br>15 - 16 junio|Dominio, Deuda<br>técnica|Lexicón completo<br>(153 glosas)|
|Validación cuantitati<br>y documentación|16 - 18 junio|Pruebas,<br>Documentación|Métricas e informe<br>final|



### **4. INGENIERÍA DEL PROYECTO** 

### **4.1. Diseño de la arquitectura  de software** 

El diseño arquitectónico de OpenSoul se fundamenta en la robustez, la escalabilidad y la separación de responsabilidades. Para lograr una solución integral en el ámbito judicial 

### Arquitectura Serverless del Modulo Isb_to_text_audio (OpenSoul) 



<!-- Start of picture text -->
4) Lambdasemantica consultaen cachéS3 eu<br>[<br>Flutter muestra texto BA<br>y reproduce audio Flutter envia API Gateway2) recibe e Sinocaché hay CachéAmazon Semantica $3:<br>f 5) giosasreper1) y e4POSTB /translate 9 6 generaAnalizaGLOSS_LEXICON oracionglosas basecon<br>Aplicacién Movil- -e-meae AWSee Lembda@ —_saBedrock;  alltPETSrefina daeaaadel texto REFINAMIENTOAmazon BedrockDE TEXTO<br>Flutter y | ry<br>Flutter Pollyaudio genera MP3 Fyvan an le<br>y reproduce uesaudioee Lambda(generatedText,retorna JSONbaseSentence, hacia Flutter ca S3 +el mtaudio<br>audioUrl, cacheHit, bedrockUsed) SINTESIS DE VOZ privado AUDIO MP3<br>Amazon Polly Amazon $3:<br>$3 genera URL Almacenamiento<br>& Leyenda: Iconos de Servicios AWS y Componentes prefirmada temporal Privado de Audio<br><!-- End of picture text -->

(*). Esta configuración facilita las pruebas e integración inicial del sistema, mientras que en un entorno productivo podría reemplazarse por una política más restrictiva basada en orígenes autorizados, mecanismos de autenticación o claves de API. 

- **AWS Lambda (Capa de Cómputo e Inteligencia Híbrida):** es el cerebro del sistema. Ejecuta código en Python 3.11 y alberga el Motor Híbrido de Traducción. En su fase determinista utiliza el GLOSS_LEXICON (diccionario de dominio jurídico boliviano) para clasificar las glosas en roles gramaticales y construir una oración base inmutable, asegurando que la intención del usuario sordo no sea alterada por alucinaciones de IA. En su fase de orquestación coordina las llamadas a Bedrock y Polly, gestionando los fallos de manera que el sistema siempre devuelva al menos la oración base segura. 

- **Amazon Bedrock (Capa de Refinamiento de IA):** provee acceso a modelos fundacionales como Anthropic Claude o Amazon Titan. En OpenSoul, Bedrock no traduce desde cero; actúa como corrector gramatical de estilo, tomando la oración base rígida y otorgándole fluidez y coherencia para producir un texto formal apto para un acta judicial. 

- **Amazon Polly (Capa de Accesibilidad Auditiva):** convierte el texto refinado en audio de alta fidelidad mediante el motor Neural TTS y la voz "Lupe" (español latinoamericano), permitiendo que el funcionario judicial reciba la declaración de forma auditiva. 

- **Amazon S3 y Presigned URLs (Capa de Almacenamiento y Privacidad):** los archivos MP3 generados se almacenan en un _bucket_ privado. Para garantizar la privacidad de la declaración, el sistema genera una URL prefirmada mediante el SDK boto3 que otorga acceso temporal de 60 minutos al audio. 

### **4.1.2. Arquitectura de la Aplicación Móvil (** **_Clean Architecture_ )** 

El _frontend_ del módulo lsb_to_text_audio está construido bajo los principios de la Arquitectura Limpia, estructurando el código en capas donde la lógica de negocio reside en el núcleo y las dependencias externas quedan en la periferia. Esta separación se refuerza mediante Riverpod para la inyección de dependencias, la gestión del estado reactivo y la coordinación del flujo de traducción. 



<!-- Start of picture text -->
Diagrama de capas y dependencias del médulo Isb_to_text_audio<br>Dependency<br>OpenSoul App UI Direction<br>Capas de Dominio (Domain)<br>eSTranslateCardsUseCase<br>(ints iitartacas00 UN<br>TranslationRepository \ Hardware<br>ion urce<br>a<br>Dependency Ce,<br>Direction<br>RemoteTranslationDataSource LocalCardsDataSource<br><!-- End of picture text -->

error, éxito), recibe la intención del usuario, llama al caso de uso y actualiza la UI con el resultado. 

- **Capa de Dominio:** es la capa más interna y contiene las reglas de negocio puras. Incluye las entidades LsbCard, SemanticZone, SemanticContext y TranslationResult (clases de Dart puro), los casos de uso TranslateCardsUseCase, GetCategoriesUseCase y GetCardsByCategoryUseCase, los servicios SemanticNavigationEngine y LocalSentenceAssembler, y los contratos abstractos CardsRepository y TranslationRepository, que definen qué operaciones se pueden realizar pero no cómo. 

- **Capa de Datos:** responsable de la persistencia y la comunicación con servicios externos. LocalCardsDataSource maneja el catálogo léxico local de más de cien tarjetas, mientras que RemoteTranslationDataSource realiza las peticiones HTTP a AWS API Gateway. Las implementaciones de repositorio deciden si recuperar los datos de la fuente local o del servidor remoto, mapeando el JSON de la API a las entidades de dominio. 

### **_3. Flujo de Ejecución (Acción: Traducir)_** 

Cuando el usuario presiona el botón "Terminé y traducir", se dispara el siguiente flujo: 



<!-- Start of picture text -->
(Dispositivo Movil Flutter)<br>2 2. Controller (loading)<br>Légica de Control<br>ie<br>oy 3. UseCase<br>2S) (TranslationUseCase)<br>ou 4, Repository<br>oe (TranslationRepository)<br>=e! (includes logic de caché ldgica)<br>E*) (AWS APIGatewayDataSource)<br>ae a, §. DataSource.<br>mut] AWS Nube 5;<br>[z)) 6. PosT a Aws API Gateway iG<br>Validar Solicitud<br>JSON Generar MD5 Cache Key<br>Consulta Caché<br>i Rasps Analisis‘ose Semantico Lambda<br>Generar Oracién Base<br>(Logica interna)<br>Refinar(Generacién con deBedrock Texto) Seeas<br>Sintetizar Polly ey<br>(Texto a Voz, TTS) gt<br>Subir a $3 =|<br>(Almacenamiento) eo<br>8. Respuesta JSON<br>(Modelo de Datos)<br>Le" 9. TranslationResultParsada fields:<br>+ text_translation: text_translation<br>*+ final_imagepolly audia _url :: pollyfinal_image audio<br>===} | 10. Ul (Dispositivo Mévil Flutter)<br>a Muestra Textoy Reproduce Audio<br>= Texto Traducida:<br>°4<br>o<br><!-- End of picture text -->

- Controller: cambia su estado a loading y ejecuta el TranslateCardsUseCase; en paralelo, el LocalSentenceAssembler construye una oración base local de respaldo. 

- Use Case: llama al TranslationRepository. 

- Repository Impl: solicita los datos al RemoteTranslationDataSource. 

- DataSource: realiza la petición POST a AWS API Gateway, que la redirige a la función Lambda. La Lambda valida el request, genera la clave de caché MD5, ejecuta el análisis semántico con el GLOSS_LEXICON, genera la oración base con reglas propias, la refina opcionalmente con Bedrock, sintetiza el audio con Polly y lo sube a S3, devolviendo un JSON. 

- Repository Impl: convierte el JSON en una entidad TranslationResult y la devuelve hacia arriba. 

- Controller: recibe la entidad, aplica el detector de degeneración para decidir entre el texto de Bedrock y la oración base local, actualiza el estado a data y la UI se reconstruye mostrando el texto y reproduciendo el audio (remoto de Polly o local con flutter_tts). 

### **4.1.3. Diagrama de Casos de Uso del Sistema** 

Este diagrama identifica las interacciones críticas en el entorno judicial. 

Actores: 

- **Persona Sorda:** usuario principal que construye su declaración en LSB. 

- **Funcionario Judicial/Policía:** usuario oyente que recibe la traducción en texto y audio. 

Casos de Uso Principales: 

- **UC1 — Seleccionar contexto situacional:** la persona usuaria selecciona uno de los contextos visibles disponibles en la aplicación: denuncia de robo, violencia, accidente, declaración como testigo u orientación/trámites legales. El contexto de orientación agrupa internamente situaciones de consulta, pérdida de objetos y trámites documentales, permitiendo que el ensamblador semántico derive el subcontexto adecuado según las glosas seleccionadas. 

- **UC2 — Construir relato con glosas LSB:** la persona sorda selecciona tarjetas de glosas guiada por las zonas semánticas priorizadas. 



<!-- Start of picture text -->
Diagrama UML de ie CCasos de de U Uso - SistSistema dede AsistAsistencia para P.Persona SordSorda<br>Sistema de Asistencia para Persona Sorda<br>BeesUC1: Seleccionar situacional maw ® &eo” Pe] ei<br>S by ZONA TA: TEXT BOXS<br>con glosas LSB 4) S<br>u ; UC4: Reproducir<br>oe UC2: Construir relato = dee<br>ga?2 aan Coenen UC3: Tradtexto y a u cd i roor) © eclaracionen audio’ FuncionariofT<br>UC5: Copiar al Judicial/Policia4 “FuP) si<br>portapapeles ©<br>(ll=]  UCS:portapapeles Copiar al ™ mya ftB VCE:nuevaIniciar= [\<br>fi declaracion<br><!-- End of picture text -->



<!-- Start of picture text -->
4.1.4. Diagrama de Clases (Dominio): Dominio del Médulo Isb_to_text_audio<br>Capa de Presentacién<br>apa de Casos de Uso<br>Capa de DominioEEE coniguriis Cards Repository<br>go ye [—Semaniczone | [—tsbeard| |__TrTi anslat onResuionResutt| Cone<br>Suingname:zones: Sti question:eer String 1." 1.2 | displayText:Roar ore String PcabaseSentence:lead Sing getCategories():: Futureclist<Category>>(Intertaz)<br> List<SemanticZone> wpencyLevel:int categoryld: String eet de getCardsByCategory(category: String): FuturecListel sbCard>>}<br>baseUrgency: int cardCategories: List<String> semanticloon: String bedcaire getAliCards(): Future<ListeLsbCard>><br>entryZoneld: String contextTags: List<String> isEmergency: boot cachedit: dation: JBON A<br>eee elect: Sting glossSequence: List<String> H<br>Se en eeeEeeeEeeEes: '<br>- H<br>—[_____SemanticNavigationEngine|= [7LocalSentencenssembier= | TranslationRepository(intertaz)<br>prioritizeCards(zone: SemanticZone): List<LsbCard> au “ cards:eae Future<TranslationResult><br>Le © oil ay od<br>\“‘a<br>‘ae ae ‘a ;<br>SS AWSAPIGatewayDataSourceRN (TranslationRepository=  impl) I” Pe TRCardsDataSourceaR(CardsRepositoryEES imp) a —p<>  sheeAssociationvs =<br>getCardsByCategory(category: String): Future<List<eLsbCard>>) ==aK Dependency<br><!-- End of picture text -->



<!-- Start of picture text -->
DIAGRAMA DE SECUENCIA: Traducci6én de LSB a Espafiol y Audio<br>(personafa1. Usuariosorda) (uderaeebence2. App Flutter poss) 3. Datasource(clientee|sHTTP)Bemoto Arquitectura(ocalSomancenssembl4, Motor LocalHibrida:| §.APIBackend Gateway1D Serverless| | (astonA6. y LambdaFallback Pyhen 2.11)Local|| f8,(elaveCaché mos)$3 | ("ese9. B xedrock raOe L| cies10.> Pollyeee) | | (bucket11.fe$3 prvado) Audio<br>i { | | i Cache Hit» true { | | |<br>| | | | | 7 Lembds invokes Bedrock with base sentence. | | H<br>| | | | | else: | | |<br>| [oe Rosie Samet? ‘ { 19. Lambda send final text to Polly for MP3. woiee Lupe). | H<br>i ‘MotorLoc return locally assembled sentenc i 12. Uploads MP3to $3 Audio, ge t ra pre-signed UBL<br>H = 16. HTTP response | H H H H<br>(personailieneagpsorda)—Semenceand plays audio}tigress2. App Flutter Qe(cliente| HTTP) | |Co=Sehiree4, Motorj Localale H Seats6. Lambda (clave8, Cachéi mos)$3 | | ("fSreaties”9. Bedrocki | | réuat10. Pollyroe{  upe) | | (b4eket11,$3 Audio privado)i<br><!-- End of picture text -->

- Estrategia de salida de audio: el sistema puede seleccionar entre reproducción de audio remoto generado por Amazon Polly o síntesis local mediante flutter_tts, según la disponibilidad de la URL remota y el estado de conectividad. 

- _Fallback_ / _Graceful Degradation_ :cuando el _backend_ falla, devuelve una respuesta incompleta o no preserva correctamente la intención de las glosas, el sistema conserva la oración base generada localmente y utiliza mecanismos de respaldo para mantener la salida textual y auditiva disponible. 

### **4.2. Implementación del módulo** **_lsb_to_text_audio_** 

La implementación del módulo lsb_to_text_audio se construyó como un flujo modular guiado por la arquitectura limpia. El catálogo local de glosas permite al usuario seleccionar palabras o conceptos visuales; posteriormente, el controlador organiza la secuencia, construye una oración base y envía la solicitud al _backend_ . La respuesta obtenida se procesa para mostrar el texto final, reproducir el audio y mantener una experiencia continua aun cuando exista una falla parcial en el servicio remoto. 

### **4.2.1. Flujo de entrada mediante tarjetas glosa** 

La entrada principal del módulo está compuesta por tarjetas visuales que representan glosas LSB. Estas tarjetas se cargan desde _LocalCardsDataSource_ , donde cada elemento contiene una glosa, un texto visible, una categoría semántica, una subcategoría, un ícono semántico y metadatos de contexto. El objetivo no es únicamente mostrar palabras, sino presentar unidades visuales que la persona usuaria pueda reconocer y seleccionar de forma rápida. 

El contenido del catálogo no fue definido de forma arbitraria. Las glosas incorporadas en _LocalCardsDataSource_ provienen de una selección técnica basada en materiales oficiales de enseñanza de la Lengua de Señas Boliviana, especialmente los módulos publicados por el Ministerio de Educación de Bolivia. A partir de ese vocabulario base se realizó una depuración funcional orientada al dominio del proyecto, conservando únicamente las glosas necesarias para construir relatos en contextos judiciales y administrativos. Por esta razón, el catálogo implementado no funciona como un diccionario general de LSB, sino como un corpus especializado para interacción institucional. 

A partir de esta recopilación se realizó una depuración funcional orientada al dominio del proyecto, conservando únicamente las glosas necesarias para construir relatos en contextos judiciales y administrativos. Por esta razón, el catálogo implementado no funciona como un diccionario general de LSB, sino como un corpus especializado para interacción institucional. Cada glosa fue normalizada dentro del sistema mediante metadatos de categoría, subcategoría, contexto funcional, prioridad, dialecto y rol semántico, permitiendo que el motor de traducción pueda interpretarla dentro de una secuencia estructurada. 

En la interfaz, el flujo comienza con _ContextSelectionWidget_ , que ofrece los contextos disponibles. Una vez elegido el contexto, la pantalla principal _HomeScreen_ despliega un flujo guiado construido con componentes como _NodeFlowCanvas_ , _CardGrid_ , _SentenceBuilder_ , _SemanticZonesBar_ y otros widgets de apoyo. Estos componentes trabajan sobre _sentenceProvider_ , _semanticZonesProvider_ y _contextProvider_ , de manera que cada selección modifica el estado global del módulo de forma reactiva. 

El sistema limita la carga inicial de opciones para reducir la saturación cognitiva. En modo guiado, el proveedor de tarjetas devuelve respuestas filtradas por zona activa, categoría y contexto, priorizando las glosas más frecuentes y relevantes. Si el usuario selecciona una tarjeta, el estado se actualiza inmediatamente y la secuencia construida se visualiza en la parte inferior de la pantalla como una frase en progreso. Este mecanismo permite que la entrada deje de ser una lista de botones y se convierta en un relato visual organizado. 

### **4.2.2. Construcción del relato y selección semántica** 

La selección de glosas no ocurre de forma aleatoria. El sistema utiliza una estructura de contextos y zonas semánticas que organiza la conversación de manera progresiva. Por ejemplo, en un contexto de denuncia se priorizan zonas como situación, personas, apariencia, vestimenta, objetos, lugar, emergencia y tiempo; en un contexto de trámites se priorizan zonas como instituciones, documentos, plazo y orientación. Cada zona define categorías y subcategorías permitidas, así como un peso semántico que influye en la navegación guiada. 

El archivo _context_provider.dart_ concentra esta lógica. Allí se definen los contextos disponibles, sus zonas semánticas y la resolución del contexto real que debe enviar el 

motor de ensamblado. En particular, el contexto fusionado orientación agrupa tarjetas de orientación, trámites y pérdida, pero el sistema puede enrutar internamente la traducción hacia pérdida o _tramite_id_ si las glosas seleccionadas lo requieren. Este detalle es importante porque evita perder coherencia semántica cuando el usuario está expresando una situación de un trámite documental. 

La selección semántica también se ve reforzada por la lógica de sugerencias. Cada tarjeta puede sugerir la siguiente mediante _suggestedNextCardIds_ , lo que permite que el sistema no solo muestre opciones válidas, sino que guíe la construcción de la declaración con una secuencia lógica. A ello se suma el motor _SemanticNavigationEngine_ , que prioriza zonas y respuestas según la intención del relato. Como resultado, el usuario no compone oraciones sueltas; construye una secuencia que el sistema interpreta como un mensaje con intención, contexto y detalles relevantes. 

### **4.2.3. Envío al** **_backend_ y procesamiento remoto** 

Cuando la persona usuaria presiona el botón de traducción, `HomeScreen` captura primero el enrutador, luego resuelve el contexto final para el ensamblador y finalmente invoca _translateCards_ en _TranslationController_ . Esta llamada es el punto de unión entre la interfaz móvil y el _backend_ remoto. 

El controlador establece el estado en carga, construye primero una oración base local con _LocalSentenceAssembler_ y luego invoca el caso de uso _TranslateCardsUseCase_ , el cual delega en _TranslationRepository_ . A su vez, el repositorio usa _RemoteTranslationDataSourceImpl_ , que realiza la petición HTTP POST a la URL del API Gateway. El cuerpo de la solicitud incluye el contexto, las glosas seleccionadas, el idioma `es-BO` y el tipo de institución, lo que permite que el _backend_ procese el mensaje con suficiente información de dominio. 

La respuesta del _backend_ devuelve datos estructurados como _baseSentence_ , _generatedText_ , _audioUrl_ , _cacheHit_ , _bedrockUsed_ , _intermediateRepresentation_ y _glossSequence_ . Esa estructura permite que la aplicación no solo muestre el texto final, sino que también conserve información sobre el procesamiento interno realizado en la nube. Si el _backend_ falla o entrega una salida poco confiable, el sistema no interrumpe el flujo: usa la oración local segura y sigue funcionando. 

### **4.2.4. Generación de texto formal** 

La generación del texto formal es el objetivo principal del módulo. El sistema transforma glosas LSB en una oración en español comprensible para un funcionario oyente, evitando que el usuario tenga que escribir manualmente una versión formal de su relato. Para lograrlo, el componente _LocalSentenceAssembler_ analiza las glosas seleccionadas y compone una base oracional con sintaxis española correcta. 

El ensamblador local no se limita a concatenar palabras. Clasifica las glosas por rol gramatical y construye frases que respetan sujeto, verbo, objeto, tiempo, lugar, emoción y contexto institucional. Por ejemplo, si el usuario selecciona glosas asociadas a robo, el sistema puede producir una estructura como “Quiero denunciar un robo. Un hombre me robó mi celular en la calle.” Si la selección está asociada a trámites, puede generar expresiones como “Quiero realizar un trámite. Quiero renovar mi licencia de conducir en el SEGIP.” Esto demuestra que la traducción no es literal, sino funcional y orientada a la claridad jurídica o administrativa. 

En el controlador de traducción, la respuesta del _backend_ se compara con la salida local mediante _isBackendDegenerate_ . Si el contenido remoto pierde información, es demasiado corto, no preserva las glosas o no conserva estructura gramatical, el sistema descarta la salida remota y conserva la versión local. Esta decisión es fundamental porque protege la intención de la persona usuaria y evita que una respuesta ambigua o incompleta llegue como declaración final. 

### **4.2.5. Generación y reproducción de audio** 

La salida del módulo es multimodal. Además del texto formal, la aplicación debe ofrecer una versión auditiva para que el funcionario oyente reciba la declaración con mayor facilidad. La gestión de audio está centralizada en el controlador de traducción, que administra dos caminos distintos: audio remoto generado por Amazon Polly y audio local generado como respaldo mediante síntesis nativa del dispositivo. Cuando el _backend_ devuelve una URL válida de audio, el sistema reproduce el MP3 y controla su estado mediante un indicador de reproducción. Si la URL no existe o la reproducción remota falla, el sistema activa la síntesis local con una configuración de español priorizada según la disponibilidad del dispositivo. Esta estrategia híbrida permite que el usuario no dependa de una única tecnología para escuchar el resultado de su declaración. La pantalla 



<!-- Start of picture text -->
Implementacion flow de Isb_to_text_ audio module for OpenSoul-like<br>enter<br>———_——_——, ns<br>f Interfaz Flutter m1) Estado iverpod Dominio local Backend remoto AWS<br>Usuario anes eee ree aws"<br>{ & =i 4 » of oe =<br>ContextSelectionWidget contextProvider oO | TranslateCardsUseCase _;,*7¢'¢ Vl RemoteTranslationDataSource<br>| Ez translation = a ts<br>NodeFlowCanvas | r) — Ge peel<br>2) Sade! ctualiza ieaige LocalSentenceAssembler —<br>00 Ga es rae +f.<br>CardGrid | ise |e SemanticNavigationEngine<br>2 \ ————<br>oe ol rats | | cy —| =<br>———al | weSLAG ven finer ts htt tts<br>Nacom atts 8<br>| DeclarationResultScreen © Pallasecuencia dede glosas resultado y controles muestratext, de audio ‘ TeNtuokReatrans! esul } 2<br>X J :<br>—> Main Flow —P Local Fallback +} Internal Data Flow<br><!-- End of picture text -->

### **4.3.1. Configuración de API Gateway** 

Amazon API Gateway funciona como la puerta de entrada del sistema. La aplicación Flutter envía una solicitud HTTP `POST` hacia un _endpoint_ REST que recibe la secuencia de glosas y el contexto situacional. En la implementación actual, el datasource remoto envía una petición con cabeceras `Content-Type: application/json` y `Accept: application/json`, lo que garantiza interoperabilidad con el _backend_ . 

Este componente no solo expone la API, sino que también actúa como capa de control de acceso y normalización de tráfico. Su función es recibir la solicitud, validar el formato y redirigirla hacia la función Lambda correspondiente. En el contexto del proyecto, esto permite tener un punto único de comunicación entre la app móvil y el sistema de traducción alojado en AWS. El endpoint REST desplegado se evidencia en la Figura F3 (Anexo F). 

### **4.3.2. Despliegue y ejecución de Lambda** 

AWS Lambda es el núcleo de ejecución del _backend_ . La función recibe la solicitud enviada desde API Gateway y procesa la entrada sin necesidad de administrar servidores físicos. En el diseño del proyecto, la función se ejecuta en Python 3.11 y concentra la lógica que interpreta las glosas, organiza el significado y devuelve una traducción formal. 

La Lambda del proyecto actúa como orquestador. Primero valida la petición, luego consulta el diccionario semántico de dominio, genera una representación base, decide si debe refinar el texto con IA y, finalmente, prepara la respuesta con el resultado textual y el enlace de audio. Este enfoque _serverless_ permite escalar el servicio de acuerdo con la demanda sin complejidad de infraestructura adicional. La ejecución de prueba del backend y el registro generado en CloudWatch se presentan en el Anexo F, Figuras F5 y F6. 

### **4.3.3. Refinamiento con Bedrock** 

Amazon Bedrock se utiliza como capa de refinamiento lingüístico. En lugar de generar una traducción desde cero, el modelo fundacional recibe una oración base previamente estructurada y la mejora para darle cohesión, estilo formal y fluidez sintáctica. Esta decisión es importante porque evita que el modelo altere libremente el sentido de la declaración. El _backend_ aplica una lógica de control para impedir desviaciones 

semánticas. El modelo fundacional no debe inventar información ni reemplazar la intención expresada por las glosas seleccionadas. Por eso, Bedrock funciona como un refinador complementario y no como el único responsable de la traducción. Si la salida del modelo no cumple con la cobertura esperada, el sistema conserva la oración base generada localmente o por reglas. El modelo fundacional utilizado Amazon Nova 2 Lite habilitado se evidencia en la Figura F4 (Anexo F). 

### **4.3.4. Síntesis de audio con Polly** 

Amazon Polly convierte la traducción textual en audio mediante síntesis neuronal. Esta etapa es clave para la accesibilidad, porque produce un archivo sonoro que puede ser escuchado por la persona oyente que recibe la declaración. Polly genera un archivo MP3 y lo entrega para almacenamiento temporal o para su reproducción directa desde la aplicación. 

El módulo del proyecto no usa el audio como elemento decorativo, sino como parte funcional del proceso de comunicación. Por eso, el audio se conserva asociado a la declaración y se reproduce desde la pantalla de resultados. La integración con Polly permite, además, mantener una voz consistente y comprensible sin depender de los recursos de síntesis del dispositivo. La síntesis de audio se verifica en la invocación de prueba de la Figura F5 (Anexo F) 

### **4.3.5. Almacenamiento temporal en S3** 

Amazon S3 se emplea como repositorio temporal de los audios generados. El archivo MP3 producido por Polly se almacena en un _bucket_ privado y no queda expuesto públicamente. Para acceder a él desde la aplicación, el _backend_ genera una URL prefirmada con validez temporal limitada. Este mecanismo protege la privacidad de la información, algo especialmente relevante en declaraciones judiciales o administrativas. El audio no debe permanecer público ni accesible de forma indefinida; por eso la URL temporal permite reproducir el contenido solo durante un periodo controlado. En el proyecto, esta lógica también refuerza el principio de manejo responsable de datos sensibles. La evidencia del almacenamiento de audios en el bucket privado de S3 se muestra en el Anexo F, Figura F7. 



<!-- Start of picture text -->
Diagrama de Integracio6n AWS del mddulo Isb_to_text_audio<br>AWS integration diagram for Isb_to_text_audio module<br>Dj\ it (MD5QueryCache hash keyor ofuptualze contextgenerated + glosses) with Amazon S3<br>POST fransate (a)= IsoNreqest | AWSLambda(Python 3.11) | Store / Retrieve cache<br>AmazonGatewayAPI Validation of input (Ni sole caching(JSONSemantic wihresponses) Cacheno )<br>, Semantic<br><w Analysis of glosses refinementlinguistic —» he4<br>Flutter Mobile Amazon Bedrock<br>Client<br>Construct of base<br>x<br>JSON response sentence Text EQ Generate MP3 Fa<br>{ \ Amazon Polly<br>baseSentence,generatedText,audioUrl, Presigned URL &<br>cacheHit,<br>bedrockUsed Amazon S3<br>} Private Audio Storage<br><!-- End of picture text -->

de forma consistente: selección de glosas, traducción, generación de texto, reproducción de audio, manejo de _fallback_ y presentación del resultado. Para ello se emplean pruebas unitarias, pruebas de integración, pruebas del datasource remoto, pruebas del controlador, pruebas de widget y pruebas de accesibilidad, de modo que cada parte del sistema pueda verificarse de forma independiente y también dentro del flujo completo. 

### **4.4.1. Validación funcional** 

La validación funcional se realizó mediante pruebas automatizadas que cubren el motor local, la cobertura semántica, el flujo completo de glosas y el arranque básico de la aplicación. En el proyecto existen pruebas unitarias, pruebas de cobertura semántica, pruebas de humo por cada glosa y prueba básica de carga de la interfaz. Todas estas pruebas se ejecutaron correctamente y confirmaron que el módulo responde a los casos previstos. 

El archivo _local_sentence_assembler_test.dart_ verifica que las oraciones producidas por el motor local tengan forma gramatical válida y que no se reduzcan a listas crudas de palabras. El archivo _semantic_coverage_test.dart_ comprueba que cada glosa quede representada dentro del texto generado y que el reenrutado de contextos fusionados no pierda contenido. Finalmente, _full_gloss_smoke_test.dart_ recorre prácticamente todo el catálogo para confirmar que el sistema genera una frase para cada glosa y cada contexto. La ejecución general de las pruebas automatizadas se evidencia en el Anexo C, Figura C1. 

**Tabla 3** **_._** 

_Matriz de pruebas automatizadas del módulo lsb_to_text_audio_ 

|**Prueba**|**Archivo**|**Propósito**|**Evidencia**|
|---|---|---|---|
|Ensamblado<br>r Local|local_sentence_assembler<br>_test.dart|Verificar generación de<br>oraciones coherentes|Anexo C|
|Cobertura<br>Semántica|semantic_coverage_test.d<br>art|Confirmar que las glosas<br>relevantes no se pierdan|Anexo C|



|Prueba de<br>Humo|full_gloss_smoke_test.dar<br>t|Recorrer el catálogo y<br>validar generación de<br>frases|Anexo C|
|---|---|---|---|
|Datasource<br>Remoto|remote_translation_dataso<br>urce_test.dart|Verificar contrato HTTP<br>y mapeo JSON|Anexo C|
|Controlador|translation_controller_test<br>.dart|Validar estados,_fallback_<br>y resultado|Anexo C|
|Flujo UI|home_to_result_flow_test<br>.dart|Comprobar navegación y<br>pantalla de resultado|Anexo C|
|Accesibilida<br>d|accessibility_semantics_t<br>est.dart|Validar etiquetas<br>semánticas y soporte a<br>lector de pantalla|Anexo C|
|Tarjetas<br>dinámicas|dynamic_cards_provider_<br>test.dart|Verificar el filtrado y<br>carga de tarjetas por<br>contexto|Anexo C|
|Validación<br>Cuantitativa|exportar_resultados_test.d<br>art|Generar el corpus de 322<br>casos y medir cobertura,<br>lexicón y compuerta|Anexo E|



Fuente: Elaboración propia, 2026. 

Las capturas de pantalla correspondientes a la ejecución de las pruebas automatizadas se presentan en el Anexo C, donde se evidencia la ejecución satisfactoria de los principales casos de validación del módulo lsb_to_text_audio. 

### **4.4.2. Validación semántica** 

La validación semántica es uno de los puntos más importantes del módulo, porque el problema del proyecto no es solo técnico sino lingüístico. El sistema debe representar correctamente la intención de la persona sorda sin perder información, sin exagerarla y sin vaciarla de contenido. Para ello, el ensamblador local clasifica cada glosa según su rol gramatical (sujeto, verbo, objeto, lugar, tiempo, rasgo, emoción, servicio, documento e institución) y compone una oración en español formal, garantizando además la cobertura 

semántica completa mediante una red de seguridad interna que asegura que ninguna glosa seleccionada quede sin representar. 

Para cuantificar esta propiedad se construyó un corpus de 322 casos de prueba —21 casos curados que reproducen flujos reales de la aplicación y 301 casos generados aleatoriamente con semilla fija (reproducibles) a partir de combinaciones válidas de glosas por contexto—. Cada caso se procesó con el motor real de la aplicación y se midió el porcentaje de glosas representadas en la oración final. El resultado fue una cobertura semántica del 100 %: en los 322 casos, ninguna glosa seleccionada por el usuario se perdió. Adicionalmente se verificó que el 100 % del catálogo léxico (153 glosas) tenga un rol gramatical asignado, condición necesaria para que toda glosa pueda integrarse en una oración 

### **_Tabla 4._** 

_Cobertura semántica del motor por contexto (322 casos)_ 

|Contexto (motor)|Casos|Cobertura Media|Glosas Promedio|
|---|---|---|---|
|denuncia_robo|64|100.0%|5.8|
|violencia|64|100.0%|5.4|
|accidente|63|100.0%|4.4|
|otro (testigo)|63|100.0%|3.5|
|tramite_id|38|100.0%|4.9|
|orientación|27|100.0%|4.4|
|pérdida|3|100.0%|4.0|
|Total|322|100.0%||



Fuente: Elaboración propia, 2026. Datos generados con el motor real de la 

aplicación. 

Las figuras correspondientes (cobertura por contexto, completitud del lexicón y distribución de roles gramaticales) se presentan en el Anexo E. Como evidencia cualitativa, la Tabla 4 muestra ejemplos de secuencias de glosas y la oración formal producida por el motor, donde se observa la concordancia de género y número, la distinción entre agresor y víctima, y la estructura sintáctica correcta. 

**_Tabla 5._** 

_Ejemplos de traducción glosa LSB - español formal_ 

|Contexto|Glosas seleccionadas|Oración generada|
|---|---|---|
|Robo|ROBAR|Quiero denunciar un robo.<br>Una persona me robó.|
|Robo|HOMBRE ALTO<br>TATUAJE ROBAR<br>CELULAR CALLE<br>NOCHE|Quiero denunciar un robo.<br>Por la noche, un hombre<br>alto, con un tatuaje me<br>robó mi celular en la<br>calle.|
|Violencia|PEGAR HOMBRE<br>ALTO MIEDO POLICIA<br>ABOGADO|Quiero reportar un caso<br>de violencia. Un hombre<br>alto me golpeó. Tengo<br>miedo. Necesito un<br>abogado. Realizaré esta<br>gestión en la policía.|
|Trámite|TRAMITAR CARNET<br>SEGIP|Quiero realizar un<br>trámite. Quiero tramitar<br>mi carnet de identidad en<br>el SEGIP.|
|Testigo|DOS PEGAR VÍCTIMA<br>MUJER PARQUE|Quiero declarar como<br>testigo lo que presencié.<br>Presencié cómo dos<br>personas golpearon a una<br>mujer en el parque.|



Fuente: Elaboración propia, 2026. 

### **4.4.3. Validación de experiencia de usuario** 

La validación de experiencia de usuario se orienta a verificar que la interfaz sea 

## Validacion técnica del mddulo Isb_to_text_audio 

- eS, 3 apeey. ee Validacion de 

- Validacién funcional Validacié6n semantica experiencia de usuario 

- ZX pruebas unitariasae (v)u cobertura de glosas Q selecciéna guiada por {63 pruebas de integracién, eS ‘== conservaci6nGf de intencién; ry & cognitivareduccion de carga 7) remotopruebas de datasource © **de** teccidéngenerada de respuesta ] navegacionde resultado hacia pantalla S prueba de humo <> fallback con <) reproduccion de audio full_gloss_smoke_test LocalSentenceAssembler remoto/local 

- « validaci6n del flujo de | coherencia entre glosas y o acciones de editar, copiar = traduccién texto formal y nueva declaracién 

Entrada con glosas LSB > Texto formal — Audio > Resultado verificable 

### **4.4.4. Validación cuantitativa de la compuerta híbrida** 

La arquitectura del módulo es híbrida: combina el motor semántico local (basado en reglas, con cobertura garantizada) con un modelo fundacional de tipo Transformer ejecutado en la nube (AWS Bedrock) que refina la redacción cuando está disponible. Para que el refinamiento remoto nunca degrade la fidelidad del mensaje crítico en un dominio judicial, el sistema incorpora una compuerta de decisión (isBackendDegenerate) que evalúa la respuesta del backend y la descarta cuando es degenerada (vacía, más corta que las glosas, sin estructura gramatical o que pierde información), recurriendo entonces a la salida local garantizada. 

Esta compuerta se validó como un clasificador binario frente a un conjunto de casos etiquetados manualmente (verdad de terreno) que incluye respuestas válidas y respuestas degeneradas representativas. La matriz de confusión resultante (Figura E4, Anexo E) muestra que la compuerta clasifica correctamente ambos tipos de salida, con los siguientes indicadores: 

**_Tabla 6._** 

_Desempeño del detector de degeneración del backend_ 

|Métrica|Valor|
|---|---|
|Exactitud|100%|
|Precisión|100%|
|Sensibilidad|100%|
|F1- Score|100%|



### Fuente: Elaboración propia, 2026. 

Estos resultados confirman que la decisión de aceptar o rechazar el refinamiento remoto es confiable: el sistema aprovecha el modelo fundacional cuando aporta una redacción fiel, pero protege al usuario sordo de pérdidas de información cuando el modelo degenera. Complementariamente, se verificó que el 100 % de las oraciones generadas contienen estructura sintáctica española (artículos, preposiciones y verbos de enlace), con 

una expansión promedio de 4.5 palabras por glosa, lo que evidencia que la salida es una oración y no una concatenación de glosas (Figura E5, Anexo E). 

### **5. CONCLUSIONES Y RECOMENDACIONES** 

### **7. BIBLIOGRAFÍA** 

[1] Estado Plurinacional de Bolivia. Constitución Política del Estado, 2009. 

[2] Estado Plurinacional de Bolivia. Ley N° 223, Ley General para Personas con Discapacidad, 2012. 

[3] Estado Plurinacional de Bolivia. Ley N° 977, Ley de la Lengua de Señas Boliviana, 2017. 

[4] Ministerio de Educación del Estado Plurinacional de Bolivia. (s.f.). _Lineamientos de educación inclusiva y modelo educativo sociocomunitario productivo_ . Recuperado de <u>https://minedu.gob.bo/</u> 

[5] Policía Boliviana. (2023). _Atención a la ciudadanía y denuncia de delitos_ . Recuperado de https://www.policia.bo/ 

[6] Defensoría del Pueblo del Estado Plurinacional de Bolivia. (2024). _Servicios y_ 

_orientación ciudadana_ . Recuperado de https://www.defensoria.gob.bo/ 

[7] Federación Boliviana de Sordos (FEBOS). (2024). _Información institucional_ . 

Recuperado de https://www.facebook.com/FederacionBolivianaDeSordos/ 

[8] Oropeza-Condori, M. et al. “Lenguaje formal de descripción para la Lengua de Señas Boliviana (LSB)”. Revista Investigación & Desarrollo, Universidad Privada Boliviana. 

[9] Universidad Franz Tamayo (UNIFRANZ). (s.f.). _Proyecto Slite: Videojuego_ 

_educativo para aprendizaje de Lengua de Señas Boliviana_ . Proyecto de innovación estudiantil. La Paz, Bolivia. Recuperado de 

<u>https://unifranz.edu.bo/blog/slite-innovador-videojuego-de-lengua-de-senas-hecho-en-uni franz/</u> 

[10] Samsung Solve for Tomorrow Bolivia. (2022). _Proyecto: Traductor de Lengua de Señas con Inteligencia Artificial_ . Programa de innovación tecnológica escolar. Recuperado de https://www.solvefortomorrow.com/ 

[11] European Sign Language Centre. (2006). _Spreadthesign: Diccionario multilingüe de lenguas de señas_ [Plataforma en línea]. Recuperado el 15 de enero de 2026, de 

<u>https://www.spreadthesign.com/</u> 

[12] Alsharif, B., Alalwany, E., Ibrahim, A., Mahgoub, I., & Ilyas, M. (2025). Real-time American Sign Language interpretation using deep learning and keypoint tracking. _Sensors_ , _25_ (7), 2138. https://doi.org/10.3390/s25072138 

[13] International Islamic University Chittagong. (2024). Sign language recognition based communication system using machine learning algorithm for vocally impaired people. _European Journal of Artificial Intelligence and Machine Learning_ . - <u>https://eu opensci.org/index.php/ejai/article/view/1067</u> 

[14] Zhou, Z., Chen, K., Li, X., Zhang, S., Wu, Y., Zhou, Y., … Chen, J. (2020). Sign-to-speech translation using machine-learning-assisted stretchable sensor arrays. _Nature Electronics_ , _3_ , 571–578. <u>https://doi.org/10.1038/s41928-020-0428-6</u> [15] SignAll Technologies. (2018). _SignAll Chat: Sistema automático de traducción de Lengua de Señas Americana a inglés_ [Plataforma tecnológica]. Budapest, Hungría. Recuperado de https://www.signall.us/ 

[16] Verma, A., Kaur, G., & Singh, W. (2015). Indian sign language animation generation system. _International Journal of Computer Science and Technology (IJCST)_ , _6_ (3). Recuperado de https://www.ijcst.com/vol63/1/24-Dr-Amit-Verma-5.pdf 

[17] Sánchez Macías, W. O., Sánchez Orozco, D. E., & Ramos Anchundia, J. M. (2025). Traductor de lengua de señas ecuatoriana mediante inteligencia artificial para la inclusión educativa. _Revista Científica Multidisciplinar G-Nerando_ , _6_ (1), 2981–2997. <u>https://doi.org/10.60100/rcmg.v6i1.548</u> 

[18] Srivastava, S., Singh, S., & Pooja. (2024). Continuous sign language recognition system using deep learning with MediaPipe Holistic. _arXiv preprint arXiv:2411.04517_ . <u>https://arxiv.org/abs/2411.04517</u> 

[19] Valverde, Samuel. (2020). Prototipo de aplicación móvil para traducir audio en español a la Lengua de Señas Boliviana. Proyecto de Grado, Universidad Católica Boliviana "San Pablo" (UCB), Unidad Académica Regional Cochabamba. 

[20] Camacho Mamani, Jhonny Kevin. (2021). Aplicación móvil LSB para traducir audio en español a la Lengua de Señas Boliviana. Tesis de Grado, Universidad Católica Boliviana "San Pablo" (UCB), Unidad Académica Regional Cochabamba. 

[21] Ministerio de Educación de Bolivia, Federación Boliviana de Sordos, Fundación Amazónica para el Desarrollo de los Sordos y Proyecto ARCA. (2010). _Curso de enseñanza de la Lengua de Señas Boliviana LSB. Módulo 1_ . La Paz, Bolivia: Ministerio de Educación. Disponible en: 

<u>https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/CURSO-DE-ENSENAN ZA-DE-LA-LENGUA-DE-SENAS-BOLIVIANA-Modulo-1.pdf</u> 

[22] Ministerio de Educación de Bolivia, Federación Boliviana de Sordos, Fundación Amazónica para el Desarrollo de los Sordos y Proyecto ARCA. (2010). _Curso de enseñanza de la Lengua de Señas Boliviana LSB. Módulo 2_ . La Paz, Bolivia: Ministerio de Educación. Disponible en: <u>https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Curso-de-ensenanza-de-l a-LSB-MODULO-2.pdf</u> 

[23]L. Bass, P. Clements y R. Kazman, _Software Architecture in Practice_ , 3.ª ed. Boston, MA, EE. UU.: Addison-Wesley, 2012. 

[24]R. C. Martin, _Clean Architecture: A Craftsman’s Guide to Software Structure and Design_ . Boston, MA, EE. UU.: Prentice Hall, 2017. 

[25]R. C. Martin, “The _Clean Architecture_ ,” The Clean Code Blog, 2012. [En línea]. Disponible: <u>https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html</u> 

[26]D. J. Anderson, _Kanban: Successful Evolutionary Change for Your Technology Business_ . Sequim, WA, EE. UU.: Blue Hole Press, 2010. 

[27]Amazon Web Services, “AWS Lambda Developer Guide.” [En línea]. Disponible: <u>https://docs.aws.amazon.com/lambda/</u> 

[28]Amazon Web Services, “Amazon Bedrock User Guide.” [En línea]. Disponible: <u>https://docs.aws.amazon.com/bedrock/</u> 

[29]Google LLC, “Flutter documentation.” [En línea]. Disponible: https://docs.flutter.dev/ [30]R. Rousselet, “Riverpod documentation.” [En línea]. Disponible: <u>https://riverpod.dev/</u> 

[31]A. Vaswani et al., “Attention is all you need,” en _Advances in Neural Information Processing Systems_ (NeurIPS), 2017. 

[32]P. J. Sadalage y M. Fowler, _NoSQL Distilled: A Brief Guide to the Emerging World of Polyglot Persistence_ . Upper Saddle River, NJ, EE. UU.: Addison-Wesley, 2012. 

[33]R. Rivest, “The MD5 Message-Digest Algorithm,” RFC 1321, Internet Engineering Task Force (IETF), 1992. 

[34]Estado Plurinacional de Bolivia, Ley N.º 1658, Ley de Reconocimiento de la Lengua de Señas Boliviana (LSB) como idioma oficial y de derechos lingüísticos de las personas sordas. La Paz, Bolivia, 31-oct-2025. 

[35]Amazon Web Services, “Amazon Polly Developer Guide.” [En línea]. Disponible: <u>https://docs.aws.amazon.com/polly/</u> 

[36] Ministerio de Educación de Bolivia, Federación Boliviana de Sordos, Fundación Amazónica para el Desarrollo de los Sordos y Proyecto ARCA. (2010). _Curso de enseñanza de la Lengua de Señas Boliviana LSB. Módulo 3_ . La Paz, Bolivia: Ministerio de Educación. Disponible en: 

<u>https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Modulos-de-ensenanza-d e-la-LSB-MODULO-3.pdf</u> 

[37] Ministerio de Educación de Bolivia, Federación Boliviana de Sordos, Fundación Amazónica para el Desarrollo de los Sordos y Proyecto ARCA. (2010). _Curso de enseñanza de la Lengua de Señas Boliviana LSB. Módulo 4_ . La Paz, Bolivia: Ministerio de Educación. Disponible en: <u>https://www.minedu.gob.bo/files/publicaciones/veaye/dgee/Curso-de-ensenanza--LS B-Mod-4.pdf</u> 

<u>[38] Autor o canal no identificado. (s.f.).</u> _<u>Prevención de la violencia</u>_ <u>[Video]. YouTube. Disponible en: https://www.youtube.com/watch?v=Mnyggw3A43g. Consultado el 19 de junio de 2026.</u> 

<u>[39] Servicio de Capacitación en Radio y Televisión para el Desarrollo, Universidad Católica Boliviana. (s.f.).</u> _<u>Primer Curso Básico de Lengua de Señas Boliviana - 18. Sustantivos</u>_ <u>[Video]. YouTube. Disponible en:</u> = <u>https://www.youtube.com/watch?v tcPJXujtVyo. Consultado el 19 de junio de 2026.</u> 

### **ANEXOS** 

### **ANEXO A GUÍA DE ENTREVISTA APLICADA EN UNIDAD EDUCATIVA DE AUDIOLOGÍA** 

**Fecha:** 15 de octubre de 2024 

**Lugar:** Unidad Educativa de Audiología "Lucy Argandoña - Fe y Alegría", Cochabamba. 

**Entrevistado:** Lic.Orlando Camacho (Tutor académico del nivel secundario). 

**Objetivo:** Identificar las prácticas comunicacionales de los estudiantes sordos en su interacción diaria y en contextos de atención externa (específicamente en entidades públicas como policía o defensorías). 

### **Preguntas realizadas:** 

¿Cuál es la primera lengua que utilizan los estudiantes para comunicarse entre ellos y con ustedes? 

¿Qué medios o herramientas utilizan los estudiantes para comunicarse cuando no hay un intérprete presente? 

¿Podría describir, paso a paso, el procedimiento que sigue un estudiante o su familia cuando necesita realizar un trámite o denuncia en una entidad pública (policía, juzgado)? 

Según su experiencia, ¿cuáles son las principales dificultades que enfrentan los estudiantes al intentar comunicarse con funcionarios públicos que no dominan LSB? ¿Han utilizado alguna vez aplicaciones tecnológicas (como traductores o diccionarios) para facilitar la comunicación en estos contextos? ¿Cuáles y con qué resultado? 

En situaciones de emergencia (por ejemplo, ser víctima de un delito), ¿cómo describiría la respuesta y la capacidad de comunicación autónoma de los estudiantes? Transcripción de respuestas clave: (Las respuestas del entrevistado fueron analizadas cualitativamente; sus afirmaciones clave se integran en la sección 1.1 del presente perfil). 

### **ANEXO B FICHAS DE OBSERVACIÓN DE PROCESOS COMUNICATIVOS** 

**Objetivo:** Describir la situación actual del proceso de comunicación entre un estudiante sordo y un administrativo/tutor en el entorno educativo, como análogo a la interacción con un funcionario público. 

**Metodología:** Observación no participante durante interacciones en las que un estudiante requería comunicar una necesidad que implicaba una secuencia de hechos (ej. explicar por qué llegó tarde, reportar un incidente). 

**Ficha de Observación N°1** 

**Fecha:** 16/10/2024 

00:01 : /Users/nathanaelalba/Documents/OpenSoul/OpenSoul/test/full_gloss_smoke_test.dart: Generar corpus completo y verificar ausencia de frases-cola Encontradas 151 glosas === CONTEXTO: denuncia_robo === === CONTEXTO: violencia === === CONTEXTO: accidente === === CONTEXTO: tramite_id === === CONTEXTO: orientacion === === CONTEXTO: perdida === === CONTEXTO: otro === Total de errores detectados: @ 00:13 : All tests passed! 

##### test 1.30.0 

test_api 0.7.10 

test_core 0.6.16 url_launcher_android 6.3.30 vector_math 2.2.0 vm_service 15.0.2 webview_flutter 4.13.1 webview_flutter_android 4.12.0 webview_flutter_wkwebview 3.25.1 

Got dependencies! 

44 packages have newer versions incompatible with dependency constraints. Try “flutter pub outdated’ for more information. 00:00 : All tests passed! 



<!-- Start of picture text -->
lorientacion-tramite_id] TRAMITAR+ANTECEDENTES+FISCAL+INTERPRETE+HOY<br>~ "Quiero realizar un traémite. Quiero tramitar mi certificado de antecedentes penales en la fiscalia.<br>ecesito un intérprete de sefias."<br>lorientacion+tramite_id] PEDIR+COPIA_DENUNCIA+PODER+JUZGADO+ABOGADO<br>~ "Quiero realizar un traémite. Quiero solicitar una copia de la denuncia y un poder notarial en el ju<br>un abogado."<br>[orientacion-orientacion] CONSULTAR+INTERPRETE+DEFENSORIA<br>~ "Necesito orientacién. Quiero consultar un intérprete de sefias en la defensoria."<br>[orientacion-tramite_id] CERTIFICADO+NOTARIA+AHORA<br>~ "Quiero realizar un tramite. Necesito tramitar un certificado en la notaria. Ocurrié ahora mismo."<br>@0:01 +2: All tests passed!<br><!-- End of picture text -->

#### Got dependencies! 

44 packages have newer versions incompatible with dependency constraints. Try “flutter pub outdated’ for more information. 00:00 : Generar corpus completo y verificar ausencia de frases-—cola Encontradas 151 glosas === CONTEXTO: denuncia_robo === === CONTEXTO: violencia === === CONTEXTO: accidente === === CONTEXTO: tramite_id === === CONTEXTO: orientacion === === CONTEXTO: perdida === === CONTEXTO: otro === Total de errores detectados: Q 00:00 : All tests passed! 

synchronized 3.4.0 test 1.30.0 test_api 0.7.10 test_core 0.6.16 url_lLauncher_android 6.3.30 vector_math 2.2.0 vm_service 15.0.2 webview_flutter 4.13.1 webview_flutter_android 4.12.0 webview_flutter_wkwebview 3.25.1 Got dependencies! 

44 packages have newer versions incompatible with dependency constraints. Try “flutter pub outdated’ for more information. 00:00 : All tests passed! 



<!-- Start of picture text -->
SeleccionaH el<br>contexto<br>Sobre qué necesitas hacer una<br>declaracién?<br>a DenunciarMe robaron / roboHurto / Asalto ,<br>_<br>] DM e nunciaagredie r on viol/ M e ncia ?<br>amenazaron / Abuso<br>Reportar accidente<br>G&) Transito / Caida / Lesion/ ?<br>Emergencia medica<br>Declarar como testigo<br>@ Presencié un robo, violencia ”<br>o accidente<br>LSB FY-> Audio Audiot-> LSB<br><!-- End of picture text -->



<!-- Start of picture text -->
—OpenSoul_~ Cambiar oO0oo0>—>s> contexto<br>a DENUNCIAR ROBO<br>Pregunta 9 de 9<br>- -<br>~Cuando paso?<br>f HOY © AHORA<br>AYER O NOCHE<br>OO<br>Secuencia construida:<br>ROBAR + HOMBRE = TATUAJE =<br>ALTO * CAPUCHA « GORRA° BL...<br>TRADUCIR<br>LSB ->3Audio Audio&-> LSB<br><!-- End of picture text -->

< Declaracion 

# Traduccion lista 

Tu declaracion ha sido generada 

ianuneien para institucion mee lous publica: 

Quiero denunciar un robo. Hoy, un hombre alto, con un tatuaje, capucha, gorra y color blanco me robo mi celular en la calle. Es 

urgente. 

~) Audio listo (local) 

Secuencia de glosas: 

ROBAR * HOMBRE *« TATUAJE »* ALTO * CAPUCHA * GORRA *+ BLANCO + CELULAR * CALLE + HOY * URGENTE 



<!-- Start of picture text -->
Saving Covertura_vexicon.csv to Copvertura_vexicon.Csv<br>Saving deteccion_backend.csv to deteccion_backend.csv<br>Saving glosas_por_rol.csv to glosas_por_rol.csv<br>Saving resultados_modelo.csv to resultados_modelo.csv<br>Casos evaluados: 322 | Glosas catalogo: 153 | Casos compuerta: 16<br>id contexto_ui contexto_motor origen glosas n_glosas salida n_palabras tiene_conector glosas_cubiertas cobertura_pct<br>Quiero<br>denunciar<br>0 i i un robo.<br>0 denuncia_robo denuncia_robo _curado ROBAR 1 Una 8 1 1 100.0<br>persona<br>me robé.<br>Quiero<br>denunciar<br>HOMBRE un robo.<br>1 1 = denuncia_robo denuncia_robo —curado ROBAR 3 Un 10 1 3 100.0<br>CELULAR hombre<br>me rob6<br>mi...<br>HOMBRE Qui<br>(NIG) denunciar<br>2 TATUAJE onraoa<br>2 denuncia_robo denuncia_robo —_curado ROBAR 7 Por la 20 1 7 100.0<br>GSA noche, un<br>CALLE eo<br>NOCHE ~<br>DOS Qui<br>FISHBORA denunciar<br>3 un robo.<br>3 denuncia_robo denuncia_robo —curado MOCHILADINERO 7 Dos 21 1 7 100.0<br>PARADA personas<br>MIEDO me roba...<br>Quiero<br>reportar un<br>4 4 violencia violencia curado AMENAZAR 1 caso de 10 1 1 100.0<br>violencia.<br>Una pers...<br><!-- End of picture text -->

|ee<br>Cobertura semant|ica|pr|omedio<br>:<br>100.00%||
|---|---|---|---|---|
|Casos<br>con cobert|ura|10|0%<br>:<br>322/322|(100.0%)|
||cas|os|cobertura_media|glosas_prom|
|contexto_motor|||||
|denuncia_robo||64|100.0|5.78|
|violencia||64|100.0|5.42|
|accidente||63|100.0|4.41|
|otro||63|100.0|3.46|
|tramite_id||38|100.0|4.89|
|orientacion||27|100.0|4.41|
|perdida||3|100.0|4.00|





<!-- Start of picture text -->
“ H1 — Cobertura semantica por contexto (motor real, 322 casos)<br>100% 100% 100% 100% 100% 100% 100%<br>100 +--- (n=64) -- (n=64) -- (n=63) -- (n=63) - (n=38) - (n=27) -- (n=3) ----<br>= 80<br>S<br>ec<br>= 60<br>%<br>He<br>e 40<br>0)<br>2<br>fo]<br>O<br>20<br>0<br>er. Noh yore™. ca cow”soe °xO garwo 10 rert®on gee\ae<br><!-- End of picture text -->



<!-- Start of picture text -->
Glosas del catalogo mapeadas en el lexicon: 153/153 (100.0%)<br>H2 — Completitud del lexicon (153 glosas del catalogo)<br>Sin rol<br>(0)<br>Mapeadas<br>(153)<br><!-- End of picture text -->



<!-- Start of picture text -->
~ Distribucion del lexicon por rol gramatical<br>rasgo 31<br>objeto 18<br>lugar 12<br>documento ll<br>verboAgresion ll<br>personaDesc i<br>verboAccion 10<br>institucion 9<br>emocion 8<br>sujeto 7<br>servicio 6<br>tiempo 6<br>urgencia 3<br>motivo 3<br>tramite 3<br>arma 2<br>personaDescPlural 2<br>0 5 10 15 20 25 30<br>Numero de glosas<br><!-- End of picture text -->



<!-- Start of picture text -->
translate-lb-dev<br>v Informaci6n general de la funci6n informacion Exportara Infrastructure Composer<br>( diagrama Ree ARNIB)  dearn:aws:lambda:us-east-1:207567777004:function:translate-Isb-la funcién<br>dev<br>D translate-Isb-dev Descripcién<br>S capas (0) .<br>Ultima modificacién<br><!-- End of picture text -->



<!-- Start of picture text -->
Variables de entorno (6)<br>Las variables de entorno que se muestran a continuacién se cifran en reposo con la clave del servicio Lambda predeterminada<br>Q Search Variables de entorno<br>Clave Valor<br>APP_PREFIX \sb-to-text-audio<br>APP_REGION us-east-1<br>BEDROCK_MODEL_ID global.amazon.nova-2-lite-v1:0<br>ENABLE_BEDROCK true<br>S3_BUCKET opensoul-Isb-audio-dev<br>VOICE_ID Lupe<br><!-- End of picture text -->



<!-- Start of picture text -->
API (2/2) (©)<br>Q Buscar API 1 fa)<br>Nombre 4 | Descripcién v }] ID v | Protocolo v | Tipo dedeconexiéde la API pu n to v | Creado v | Security policy v | API status v<br>api-devSa 5kc2fwqb49 HTTP Regional 2026-03-27 - -<br><!-- End of picture text -->



<!-- Start of picture text -->
rs | Por:NovaAmazon2 Lite| ®<br>Nova 2 Lite is an advanced multimodal model geared towards adaptive reasoning, efficient thinking,<br>customization and agentic workflows.<br>Informacion general En esta pagina<br>Nova 2 Lite is an advanced multimodal reasoning model that intelligently balances performance and efficiency by | Informacién general<br>dynamically adjusting reasoning depth based on task complexity. With flexible controls for developers to adjust the Precios<br>reasoning process, Nova2 Lite delivers superior results for agentic workflows across software development, consumer<br>experiences and enterprise applications. Uso<br>Detalles<br>Vendido por Amazon<br>Categorias Image<br>Video<br>Text to Text<br>Ultima version v1<br>Fecha de lanzamiento Tue, 02 Dec 2025 08:00:00 GMT<br>ID del modelo ff) amazon.nova-2-lite-v1:0<br>Input modalities Text, Image, Video<br>Output modalities Text<br><!-- End of picture text -->

PROBLEMS OUTPUT CODEREFERENCELOG TERMINAL Execution Results VIR Os * Xx { \"Lsb-videos/CALLE.mp4\", \"recognized\": true, \"rol\": \"LUGAR\"}, {\"gloss\": \"NOCHE\", \"videoKey\": \"lsb-videos/NOCHE.mp4\", \"recognized\": true, \"rol\": \"TIEMPO\"}], \"bedrockUsed\": true, \"audioUrl\": \"https://opensoul-lsb-audio-dev.s3.amazonaws.com/ Asb-to-text-audio/0a85787e95c f f3c1a938f fa639ab777a.mp3?AWSAccessKeyId=ASIATAVAASTWMNHKDGELGS ignature=rc1CUpz5L4sZduergMqeaWcwFQ8%3D& x-amz-security—token=1Q0Jb3JpZ2 LuX2Vj EOX%2F%2F%2F%2F%2 F%2F%2F%2F%2F%2FwEaCXVZLWVhc3QtMSJHMEUCIQDPEq@AriazTwY i1SW8qZ%2B LP7 AwhgYNu7vPMnAxcc1xRAIgF88F TfyuX LKHDSpgF6LYtTFMGCV8cLNX1AHb181Wx6Y q9QMI rv%2F%2F%2F%2F%2F%2 F%2F%2 F%2F%2F ARAAGGWyMDC1Nj c3NZCWMDQiDNHFMR%2BThnSaTd LFcirJAxsSgjQjLrQtiB4EgPulFeiaU @Yt j bveB6WJbgj FFEz4ayYaAYz63j bkzP5SmTL7mXDtwmw\%2BEEIU2ALehj TMbiBQJ rsQ6wP%2FsyAvb3VJkAGECFU2MbYTteh7ytUI7PqXwaZVCm5EgjN%2FZQFCyDThG70a 1Bj fqoWuwctgU® KNMUYBWp6SMjU9bB5 LLYr9HX8Lm20PBFcpqt rB3Jkv1xCqKVf0SZ5%2F%2FwxxWIR@QpSqrRXs10F LYVvSmuzRGkvP%2BgLeKORKcM8Kf%2FgaurrADJa7eRYY 1GKYCnV2EBauWWYRNxuk fAfWoS f OmyvCDgpLwiCCCsnkk5nd9W434RFbcswGxc f031m@udkVEIpFFZZrfTEKBy2J60r8VPjgoMFLj Lpai@ZMyF56Uj j YZGI%2B15 rtdWOtTWoXL9uoc4dELnSRj Qw9c5MS5nalj rKGRAKGyDzxMjA 38KZ@HgvV1krJCitbwft%2BEZCUWKRV2nvzZt IHQKxY iwa8eEHVCUp6qgcy3R3aFNJEUnyM9m6dz5BTTPT3IN2ZAkVcatOyWFT kuUQY2eMWdb8x0A3m50@16vAh8gmdMbreozze@dLdM5Gej cxhfEh QZSg9ZWUT7RC%2FuiYwsKZzR@QY60QF iRoj orOWVPqgCc8Cj pl0omG26T3cj toTK218QLPs10Z6hs1%2BsKKt%*2BbbWsnNfG5 LU1SFXcmNROV%2BdJ tnKvG1ZDaAhXGEBwaZ5pLF7%2BXcsF79kh s1ZIehhBrAZMnek%2BRek4k3YHZT6bMnuv0z IDqgBM1WYOKk%2BVITLCYDoh4 lKQpjQInIIk1F10R%2BnSkMkweFONxZQQHWRTXLkOzx LShGiDA%3D%3D&Expires=1781818432\", \"cacheHit\": true}" 

} 

The area below shows the last 4 KB of the execution log. 

Function Logs: START RequestId: e25ca413-851e-4a15-b9c2—add58f060498 Version: $LATEST [INFO] 2026-06-18T20:33:52.767Z e25ca413-851e-4a15-b9c2-add58f060498 Solicitud recibida — request_id: e25ca413-851e-4a15-b9c2-add58f060498 [INFO] 2026-@6-18T20:33:52.767Z e25ca413-851e-4a15-b9c2—add58f060498 Procesando — cards: ['HOMBRE', 'ROBAR', 'CELULAR', ‘CALLE', 'NOCHE'], context: denuncia_robo, institutionType: entidad_publica, language: es-BO, cache_key: 0a85787e95cff3c1a938ffa639ab777a [INFO] 2026-@6-18T20:33:52.943Z e25ca413-851e-4a15-b9c2-add58f060498 Cache HIT — respuesta servida desde caché: 0a85787e95cf f3c1a938f fa639ab777a END RequestId: e25ca413-851e—4a15-—b9c2-add58f060498 REPORT RequestId: e25ca413-851e-—4a15-b9c2-add58f060498 Duration: 194.38 ms Billed Duration: 736 ms Memory Size: 256 MB Max Memory Used: 98 MB Init Duration: 540.67 ms Request ID: e25ca413-851e-—4a15—b9c2—add58f060498 



<!-- Start of picture text -->
aws,aws @ th= | Q loggroups G Preguntar a AmazonQ X b. Q& © — B__ Estados Unidos (Norte de Virginia) ¥ nuthella9Soks<br>= Query1 + Ayuda © Comentarios © Preferencias<br>© Le damos la bienvenida a la nueva experiencia de Analisis de registros. Andlisis de registros combina Informacién de registros, Live Tail e Informacién de colaboradores en una experiencia unificada<br>Al hacer clic en Aceptar, establece Analisis de registros como su opcién predeterminada a partir de ahora. Si opta por no participar, vuelve a la experiencia anterior. Administre esta preferencia en Aceptar arse de baja<br>cualquier momento desde el menti de preferencias en la parte superior derecha<br>% Pidale a la IA que escri rsult 5m 30m 1h 3h 12h Last lweek = Z aria: UTC<br>Etiquetas de grupos de registro Data sources @ % @aws.region @data_format @data_source_name @data_source_type<br>Todos los grupos de registro grupo: t Navegar Standard 8 oe 9 Live Tail 1 TopN<br>1 ( STANDARD") 604800s 0s|<br>I 10000<br>rec estadisticas que L li at e<br>Campos detectados (10<br>.> Le damos la bienvenida a Anilisis de registros QUE INCLUYE ee ><br>Informacién deInformaciéncolaboradoresde registros, Live Tail Consultas guardadas =i) Query historyA<br>PROBAR UNA CONSULTA<br>25 most recently added log events . .<br>@timestamp, @message | sm Flujo de trabajo con varias pestafias Nuevo Live Tail Nuevo<br>List of log events that are not excepti... i r % t<br><!-- End of picture text -->



<!-- Start of picture text -->
opensoul-lsb-audio-dev informacisn<br>Objetos Metadatos Propiedades Permisos Métricas Administracion Sistemas de archivos: nuevos Puntos de acceso<br>Objetos (1)<br>©<br>Los objetos son las entidades fundamentales que se almacenan en Amazon S3. Puede utilizar el inventario de Amazon $3 1” para obtener una lista de todos los objetos de su<br>bucket. Para que otras personas obtengan acceso a sus objetos, tendra que concederles permisos de forma explicita. Mas informacién 2<br>Q Buscar objetos por prefijo 1 8<br>Nombre 4 | Tipo v | Ultima modificacion v | Tamaiio v | Clasedealmacenamiento ¥ |<br>(DB Isb-to-text-audio/ Carpeta - - -<br><!-- End of picture text -->

