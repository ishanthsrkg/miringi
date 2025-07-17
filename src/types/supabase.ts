export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      balances: {
        Row: {
          btc: number
          created_at: string
          dzd: number
          eth: number
          eur: number
          frozen_balance: number
          gbp: number
          id: string
          investment_balance: number
          pending_balance: number
          savings_balance: number
          total_earned: number
          total_spent: number
          updated_at: string
          usd: number
          user_id: string
        }
        Insert: {
          btc?: number
          created_at?: string
          dzd?: number
          eth?: number
          eur?: number
          frozen_balance?: number
          gbp?: number
          id?: string
          investment_balance?: number
          pending_balance?: number
          savings_balance?: number
          total_earned?: number
          total_spent?: number
          updated_at?: string
          usd?: number
          user_id: string
        }
        Update: {
          btc?: number
          created_at?: string
          dzd?: number
          eth?: number
          eur?: number
          frozen_balance?: number
          gbp?: number
          id?: string
          investment_balance?: number
          pending_balance?: number
          savings_balance?: number
          total_earned?: number
          total_spent?: number
          updated_at?: string
          usd?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "balances_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      cards: {
        Row: {
          activation_date: string | null
          atm_withdrawals_enabled: boolean | null
          card_name: string | null
          card_number: string
          card_type: string
          contactless_enabled: boolean | null
          created_at: string
          current_daily_spent: number
          current_monthly_spent: number
          cvv: string | null
          daily_limit: number
          expiry_date: string | null
          freeze_reason: string | null
          id: string
          international_payments_enabled: boolean | null
          is_frozen: boolean
          last_used: string | null
          monthly_limit: number
          notifications_enabled: boolean | null
          online_payments_enabled: boolean | null
          pin_hash: string | null
          security_features: Json | null
          spending_limit: number
          status: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          activation_date?: string | null
          atm_withdrawals_enabled?: boolean | null
          card_name?: string | null
          card_number: string
          card_type: string
          contactless_enabled?: boolean | null
          created_at?: string
          current_daily_spent?: number
          current_monthly_spent?: number
          cvv?: string | null
          daily_limit?: number
          expiry_date?: string | null
          freeze_reason?: string | null
          id?: string
          international_payments_enabled?: boolean | null
          is_frozen?: boolean
          last_used?: string | null
          monthly_limit?: number
          notifications_enabled?: boolean | null
          online_payments_enabled?: boolean | null
          pin_hash?: string | null
          security_features?: Json | null
          spending_limit?: number
          status?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          activation_date?: string | null
          atm_withdrawals_enabled?: boolean | null
          card_name?: string | null
          card_number?: string
          card_type?: string
          contactless_enabled?: boolean | null
          created_at?: string
          current_daily_spent?: number
          current_monthly_spent?: number
          cvv?: string | null
          daily_limit?: number
          expiry_date?: string | null
          freeze_reason?: string | null
          id?: string
          international_payments_enabled?: boolean | null
          is_frozen?: boolean
          last_used?: string | null
          monthly_limit?: number
          notifications_enabled?: boolean | null
          online_payments_enabled?: boolean | null
          pin_hash?: string | null
          security_features?: Json | null
          spending_limit?: number
          status?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cards_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      investments: {
        Row: {
          actual_profit: number
          amount: number
          auto_renew: boolean | null
          compound_interest: boolean | null
          created_at: string
          early_withdrawal_penalty: number | null
          end_date: string
          expected_profit: number | null
          id: string
          maturity_date: string | null
          payment_frequency: string | null
          product_name: string
          profit_rate: number
          risk_level: string | null
          start_date: string
          status: string | null
          terms_accepted: boolean
          total_return: number | null
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          actual_profit?: number
          amount: number
          auto_renew?: boolean | null
          compound_interest?: boolean | null
          created_at?: string
          early_withdrawal_penalty?: number | null
          end_date: string
          expected_profit?: number | null
          id?: string
          maturity_date?: string | null
          payment_frequency?: string | null
          product_name?: string
          profit_rate: number
          risk_level?: string | null
          start_date: string
          status?: string | null
          terms_accepted?: boolean
          total_return?: number | null
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          actual_profit?: number
          amount?: number
          auto_renew?: boolean | null
          compound_interest?: boolean | null
          created_at?: string
          early_withdrawal_penalty?: number | null
          end_date?: string
          expected_profit?: number | null
          id?: string
          maturity_date?: string | null
          payment_frequency?: string | null
          product_name?: string
          profit_rate?: number
          risk_level?: string | null
          start_date?: string
          status?: string | null
          terms_accepted?: boolean
          total_return?: number | null
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "investments_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          action_text: string | null
          action_url: string | null
          category: string | null
          created_at: string
          delivery_channels: string[] | null
          expires_at: string | null
          id: string
          is_archived: boolean
          is_read: boolean
          message: string
          metadata: Json | null
          priority: number | null
          read_at: string | null
          sent_via_email: boolean | null
          sent_via_push: boolean | null
          sent_via_sms: boolean | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          action_text?: string | null
          action_url?: string | null
          category?: string | null
          created_at?: string
          delivery_channels?: string[] | null
          expires_at?: string | null
          id?: string
          is_archived?: boolean
          is_read?: boolean
          message: string
          metadata?: Json | null
          priority?: number | null
          read_at?: string | null
          sent_via_email?: boolean | null
          sent_via_push?: boolean | null
          sent_via_sms?: boolean | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          action_text?: string | null
          action_url?: string | null
          category?: string | null
          created_at?: string
          delivery_channels?: string[] | null
          expires_at?: string | null
          id?: string
          is_archived?: boolean
          is_read?: boolean
          message?: string
          metadata?: Json | null
          priority?: number | null
          read_at?: string | null
          sent_via_email?: boolean | null
          sent_via_push?: boolean | null
          sent_via_sms?: boolean | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          bonus_amount: number
          campaign_id: string | null
          completion_date: string | null
          completion_requirements: Json | null
          created_at: string
          expires_at: string | null
          id: string
          referral_code: string
          referred_id: string
          referrer_id: string
          requirements_met: Json | null
          reward_amount: number
          source: string | null
          status: string | null
          tier_level: number | null
          total_reward: number | null
        }
        Insert: {
          bonus_amount?: number
          campaign_id?: string | null
          completion_date?: string | null
          completion_requirements?: Json | null
          created_at?: string
          expires_at?: string | null
          id?: string
          referral_code: string
          referred_id: string
          referrer_id: string
          requirements_met?: Json | null
          reward_amount?: number
          source?: string | null
          status?: string | null
          tier_level?: number | null
          total_reward?: number | null
        }
        Update: {
          bonus_amount?: number
          campaign_id?: string | null
          completion_date?: string | null
          completion_requirements?: Json | null
          created_at?: string
          expires_at?: string | null
          id?: string
          referral_code?: string
          referred_id?: string
          referrer_id?: string
          requirements_met?: Json | null
          reward_amount?: number
          source?: string | null
          status?: string | null
          tier_level?: number | null
          total_reward?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "referrals_referred_id_fkey"
            columns: ["referred_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_goals: {
        Row: {
          auto_save: boolean | null
          auto_save_amount: number | null
          auto_save_frequency: string | null
          category: string
          color: string
          completion_date: string | null
          created_at: string
          current_amount: number
          deadline: string
          description: string | null
          icon: string
          id: string
          monthly_target: number
          name: string
          priority: number | null
          progress_percentage: number | null
          reward_amount: number | null
          status: string | null
          target_amount: number
          updated_at: string
          user_id: string
        }
        Insert: {
          auto_save?: boolean | null
          auto_save_amount?: number | null
          auto_save_frequency?: string | null
          category?: string
          color?: string
          completion_date?: string | null
          created_at?: string
          current_amount?: number
          deadline: string
          description?: string | null
          icon?: string
          id?: string
          monthly_target?: number
          name: string
          priority?: number | null
          progress_percentage?: number | null
          reward_amount?: number | null
          status?: string | null
          target_amount: number
          updated_at?: string
          user_id: string
        }
        Update: {
          auto_save?: boolean | null
          auto_save_amount?: number | null
          auto_save_frequency?: string | null
          category?: string
          color?: string
          completion_date?: string | null
          created_at?: string
          current_amount?: number
          deadline?: string
          description?: string | null
          icon?: string
          id?: string
          monthly_target?: number
          name?: string
          priority?: number | null
          progress_percentage?: number | null
          reward_amount?: number | null
          status?: string | null
          target_amount?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "savings_goals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      security_logs: {
        Row: {
          created_at: string
          description: string
          device_fingerprint: string | null
          event_type: string
          id: string
          ip_address: unknown | null
          location: Json | null
          metadata: Json | null
          resolved: boolean | null
          resolved_at: string | null
          resolved_by: string | null
          severity: string | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string
          description: string
          device_fingerprint?: string | null
          event_type: string
          id?: string
          ip_address?: unknown | null
          location?: Json | null
          metadata?: Json | null
          resolved?: boolean | null
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string
          description?: string
          device_fingerprint?: string | null
          event_type?: string
          id?: string
          ip_address?: unknown | null
          location?: Json | null
          metadata?: Json | null
          resolved?: boolean | null
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "security_logs_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "security_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      system_settings: {
        Row: {
          category: string | null
          created_at: string
          description: string | null
          id: string
          is_public: boolean | null
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          category?: string | null
          created_at?: string
          description?: string | null
          id?: string
          is_public?: boolean | null
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          category?: string | null
          created_at?: string
          description?: string | null
          id?: string
          is_public?: boolean | null
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      transactions: {
        Row: {
          amount: number
          category: string | null
          created_at: string
          currency: string | null
          description: string
          device_info: Json | null
          exchange_rate: number | null
          failure_reason: string | null
          fee: number
          id: string
          ip_address: unknown | null
          location: Json | null
          metadata: Json | null
          net_amount: number | null
          processed_at: string | null
          recipient: string | null
          recipient_account: string | null
          reference: string | null
          sender_account: string | null
          status: string | null
          type: string
          updated_at: string
          user_id: string
        }
        Insert: {
          amount: number
          category?: string | null
          created_at?: string
          currency?: string | null
          description: string
          device_info?: Json | null
          exchange_rate?: number | null
          failure_reason?: string | null
          fee?: number
          id?: string
          ip_address?: unknown | null
          location?: Json | null
          metadata?: Json | null
          net_amount?: number | null
          processed_at?: string | null
          recipient?: string | null
          recipient_account?: string | null
          reference?: string | null
          sender_account?: string | null
          status?: string | null
          type: string
          updated_at?: string
          user_id: string
        }
        Update: {
          amount?: number
          category?: string | null
          created_at?: string
          currency?: string | null
          description?: string
          device_info?: Json | null
          exchange_rate?: number | null
          failure_reason?: string | null
          fee?: number
          id?: string
          ip_address?: unknown | null
          location?: Json | null
          metadata?: Json | null
          net_amount?: number | null
          processed_at?: string | null
          recipient?: string | null
          recipient_account?: string | null
          reference?: string | null
          sender_account?: string | null
          status?: string | null
          type?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "transactions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          account_limits: Json | null
          account_number: string
          created_at: string
          currency: string | null
          email: string
          full_name: string
          id: string
          is_active: boolean | null
          is_verified: boolean | null
          join_date: string
          kyc_documents: Json | null
          kyc_status: string | null
          language: string | null
          last_login: string | null
          location: string | null
          login_count: number | null
          notification_preferences: Json | null
          phone: string | null
          privacy_settings: Json | null
          profile_image: string | null
          referral_code: string | null
          referral_earnings: number
          risk_score: number | null
          security_level: string | null
          two_factor_enabled: boolean | null
          updated_at: string
          used_referral_code: string | null
          verification_status: string | null
        }
        Insert: {
          account_limits?: Json | null
          account_number: string
          created_at?: string
          currency?: string | null
          email: string
          full_name?: string
          id: string
          is_active?: boolean | null
          is_verified?: boolean | null
          join_date?: string
          kyc_documents?: Json | null
          kyc_status?: string | null
          language?: string | null
          last_login?: string | null
          location?: string | null
          login_count?: number | null
          notification_preferences?: Json | null
          phone?: string | null
          privacy_settings?: Json | null
          profile_image?: string | null
          referral_code?: string | null
          referral_earnings?: number
          risk_score?: number | null
          security_level?: string | null
          two_factor_enabled?: boolean | null
          updated_at?: string
          used_referral_code?: string | null
          verification_status?: string | null
        }
        Update: {
          account_limits?: Json | null
          account_number?: string
          created_at?: string
          currency?: string | null
          email?: string
          full_name?: string
          id?: string
          is_active?: boolean | null
          is_verified?: boolean | null
          join_date?: string
          kyc_documents?: Json | null
          kyc_status?: string | null
          language?: string | null
          last_login?: string | null
          location?: string | null
          login_count?: number | null
          notification_preferences?: Json | null
          phone?: string | null
          privacy_settings?: Json | null
          profile_image?: string | null
          referral_code?: string | null
          referral_earnings?: number
          risk_score?: number | null
          security_level?: string | null
          two_factor_enabled?: boolean | null
          updated_at?: string
          used_referral_code?: string | null
          verification_status?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      create_notification: {
        Args: {
          p_user_id: string
          p_type: string
          p_title: string
          p_message: string
          p_category?: string
          p_priority?: number
          p_action_url?: string
          p_action_text?: string
          p_metadata?: Json
        }
        Returns: string
      }
      generate_account_number: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      generate_card_number: {
        Args: { card_type?: string }
        Returns: string
      }
      generate_referral_code: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      get_complete_user_data: {
        Args: { p_user_id: string }
        Returns: Json
      }
      log_security_event: {
        Args: {
          p_user_id: string
          p_event_type: string
          p_description: string
          p_severity?: string
          p_ip_address?: unknown
          p_user_agent?: string
          p_metadata?: Json
        }
        Returns: string
      }
      setup_google_user: {
        Args: {
          p_user_id: string
          p_email: string
          p_full_name?: string
          p_referral_code?: string
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DefaultSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof Database },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
  ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
