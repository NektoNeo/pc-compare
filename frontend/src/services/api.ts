// API service for PC Build Comparator

export interface PCBuild {
  id: string;
  company: string;
  title: string;
  description: string;
  price: number;
  price_formatted: string;
  cpu: string;
  gpu: string;
  ram: string;
  case_color: string;
  photo_url: string;
  vk_url: string;
  is_our_build: boolean;
  price_comparison?: 'cheaper' | 'more_expensive' | 'equal';
}

export interface ComparisonRequest {
  build_id: string;
  comparison_type: string;
}

export interface ParseRequest {
  group_ids: number[];
  source: string;
}

export class PCBuildsAPI {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000/api';
  }

  async getOurBuilds(): Promise<PCBuild[]> {
    const response = await fetch(`${this.baseUrl}/builds/our`);
    if (!response.ok) {
      throw new Error('Failed to fetch our builds');
    }
    return response.json();
  }

  async getBuild(id: string): Promise<PCBuild> {
    const response = await fetch(`${this.baseUrl}/builds/${id}`);
    if (!response.ok) {
      throw new Error('Build not found');
    }
    return response.json();
  }

  async compareByPrice(buildId: string): Promise<PCBuild[]> {
    const response = await fetch(`${this.baseUrl}/compare/price`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        build_id: buildId, 
        comparison_type: 'price' 
      })
    });
    if (!response.ok) {
      throw new Error('Comparison failed');
    }
    return response.json();
  }

  async compareBySpecs(buildId: string): Promise<PCBuild[]> {
    const response = await fetch(`${this.baseUrl}/compare/specs`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        build_id: buildId, 
        comparison_type: 'specs' 
      })
    });
    if (!response.ok) {
      throw new Error('Comparison failed');
    }
    return response.json();
  }

  async startParsing(groupIds: number[], source: string = 'market'): Promise<any> {
    const response = await fetch(`${this.baseUrl}/parse/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        group_ids: groupIds, 
        source: source 
      })
    });
    if (!response.ok) {
      throw new Error('Failed to start parsing');
    }
    return response.json();
  }

  async getStatistics(): Promise<any> {
    const response = await fetch(`${this.baseUrl}/stats`);
    if (!response.ok) {
      throw new Error('Failed to fetch statistics');
    }
    return response.json();
  }

  async searchBuilds(params: {
    q?: string;
    cpu?: string;
    gpu?: string;
    min_price?: number;
    max_price?: number;
    company?: string;
  }): Promise<PCBuild[]> {
    const queryParams = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined) {
        queryParams.append(key, value.toString());
      }
    });
    
    const response = await fetch(`${this.baseUrl}/search?${queryParams}`);
    if (!response.ok) {
      throw new Error('Search failed');
    }
    return response.json();
  }
}
