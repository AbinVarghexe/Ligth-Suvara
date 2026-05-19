import os
import docx
import PyPDF2

def extract_docx(file_path):
    try:
        doc = docx.Document(file_path)
        full_text = []
        for para in doc.paragraphs:
            full_text.append(para.text)
        return '\n'.join(full_text)
    except Exception as e:
        return f"Error reading docx: {e}"

def extract_pdf(file_path):
    try:
        text = ""
        with open(file_path, "rb") as f:
            reader = PyPDF2.PdfReader(f)
            for page in reader.pages:
                text += page.extract_text() + "\n"
        return text
    except Exception as e:
        return f"Error reading pdf: {e}"

files = {
    'guidelines.txt': r'd:\LightSuvaraUI\Ligth-Suvara\assets\Miniproject Report guidelines 2023 batch.docx',
    'format.txt': r'd:\LightSuvaraUI\Ligth-Suvara\assets\Mini Project Format edited.pdf',
    'sample.txt': r'd:\LightSuvaraUI\Ligth-Suvara\assets\sample report (1).pdf'
}

for out_file, in_file in files.items():
    print(f"Processing {in_file}")
    if in_file.endswith('.docx'):
        content = extract_docx(in_file)
    else:
        content = extract_pdf(in_file)
    
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Extraction complete.")
