# DeVCopy
Pipeline para el cálculo y la generación de los metadatos nesecarios para entrenar el modelo posteriormente.

El script original es propio de un proyecto previo de Sequentia Bioetch. Las versiones posteriores son hechas por mi por diferentes razones:

- Reducir la memoria que utiliza el proceso. Ya que, en el proyecto previo solo se usaban datasets de targeted sequencing que no consumian demasiado.Sin embargo yo tuve que probar el modelo en WES por lo que tuve que modificar la pipeline.
- Adaptar la pipeline a diferentes datasets. En el transcurso del TFM y al ver que no daba buenos resultados tuve que probar diferentes estrategias que modificaban los datos y las tablas finales que genera la pipeline. Al ser una pipeline que no está muy generalizada tuve que ir cambiando ciertos aspectos para evitar errores.