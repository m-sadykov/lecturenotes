export type TranscriptResponse = {
  text: string;
  language?: string;
};

export type StudyPack = {
  title: string;
  summaryShort: string;
  summaryLong: string;
  flashcards: Array<{
    question: string;
    answer: string;
  }>;
  quiz: Array<{
    question: string;
    options: string[];
    correctIndex: number;
  }>;
};

export type ResponsesAPIResponse = {
  output?: Array<{
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
  output_text?: string;
};
