pandoc "final copy.md" -o poročilo_dolgo.pdf \
--pdf-engine=wkhtmltopdf \
--metadata pagetitle="Poročilo RSO" \
-V margin-top=0.7in -V margin-bottom=0.7in -V margin-left=0.6in -V margin-right=0.6in \
--css <(echo "
  body { 
    font-family: 'Times New Roman', Times, serif; 
    font-size: 10pt; 
    line-height: 1.15;
    text-align: justify;
    column-count: 2;
    column-gap: 24pt;
  }
  
  /* Naslov čez oba stolpca */
  h1 { 
    column-span: all; 
    text-align: center; 
    font-size: 18pt;
    font-weight: bold;
    margin-bottom: 15pt;
    text-transform: uppercase;
  }

  /* Podnaslovi (poglavja) */
  h2 { 
    font-size: 11pt;
    text-transform: uppercase;
    border-bottom: 0.5pt solid #000;
    margin-top: 12pt;
    margin-bottom: 4pt;
  }

  h3 { font-size: 10pt; margin-top: 8pt; margin-bottom: 2pt; }

  /* Strnjene alineje */
  ul, ol { 
    padding-left: 12pt; 
    margin-bottom: 6pt; 
  }
  
  li { margin-bottom: 2pt; }

  /* Slike v enem stolpcu */
  img { 
    width: 100%; 
    height: auto;
    margin: 8pt 0;
  }

  /* Horizontalne črte čez oba stolpca */
  hr { 
    column-span: all; 
    border: none; 
    border-top: 1pt solid black; 
    margin: 10pt 0; 
  }
")